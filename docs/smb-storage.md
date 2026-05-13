# Persistent storage via SMB

This cluster mounts an SMB share from a NAS on every client node and exposes
it to Nomad jobs as a bind mount. This document explains the model, why it
was chosen over the alternatives, and how to use it from a job.

## The model

- Every client node mounts the same SMB share at the configured mount point
  (`clusterConfig.nas.mountPoint` in `flake.nix`, defaulting to
  `/mnt/nas/vault`) via CIFS, using credentials stored encrypted in
  `secrets/smb.yaml` (see [sops-nix.md](./sops-nix.md)). Vault is the name
  of my main NAS, but this can be changed to whatever you'd prefer.
- The whole thing can be turned off by setting `clusterConfig.nas.enable =
  false` in `flake.nix`. With it disabled, clients come up without
  `cifs-utils`, no credentials secret is required, and nothing is mounted.
- The mount is lazy (`x-systemd.automount`): the kernel mounts on first
  access and unmounts after 10 minutes idle. Jobs that don't touch the share
  don't pay for it.
- The Nomad Docker driver has `volumes.enabled = true`, which lets jobs
  bind-mount arbitrary host paths into containers without registering a
  named volume up-front.
- Each job stores its data under `/mnt/nas/vault/<jobname>/`. The directory
  is created on first write — no setup step per new job.

Because every client mounts the same share, an alloc can move between nodes
and still see the same data. That's the whole reason network storage is in
play here.

## Why SMB (and not something more clever)

My cluster runs three categories of state:

1. **Bulk app state** — Grafana dashboards, Plex config, app data dirs,
   media, configs. Doesn't need fsync semantics, doesn't lock files, often
   bulky.
2. **Databases** — Postgres, MariaDB, anything with WAL/locking/fsync
   correctness requirements.
3. **Ephemeral scratch** — caches, build artifacts, anything fine to lose
   on reschedule.

These have different needs, so they live in different places:

| Category | Where | Why |
| --- | --- | --- |
| Bulk app state | SMB share on the NAS (this doc) | Free reschedules, NAS handles snapshots/backups, SMB is fine for non-locking workloads |
| Databases | Docker on the NAS directly | Local-disk fsync semantics; NAS handles durability; no network in the data path |
| Ephemeral | Container layer / local disk | Cheap, fast, dies with the alloc |

Things deliberately avoided:

- **CSI plugins** — none of the open-source CSI drivers support my NAS as a
  storage backend. A generic NFS/SMB CSI driver would just be re-implementing
  what host-level mounts already do, with more moving parts. If yours is
  supported, this may be a better option for you.
- **iSCSI** — would give real block storage with proper fsync, but it's
  single-initiator (only one node at a time), so it doesn't solve
  reschedule-anywhere. It's also operationally heavier than running the DB
  on the NAS directly. But it would have no advantages on the cluster since
  you still end up with a single point of failure.
- **Nomad host volumes / dynamic host volumes** — would require registering
  each volume by name in the client config or via CLI before a job can use
  it. Bind mounts to paths under `/mnt/nas/vault/<jobname>/` need zero
  setup per volume.

The trade-off accepted: any Nomad job can bind-mount any host path
(`volumes.enabled = true`). In a multi-tenant cluster that would be a
serious concern; here, every job is written or audited by the operator, so
it matches the existing trust model (same level as `allow_privileged = true`
and `dropPrivileges = false`, which are also on).

## Caveats — read these before designing a job

1. **Do not put databases on the SMB share.** SMB locking is unreliable
   (the mount uses `nobrl` to disable byte-range locks). Postgres, MariaDB,
   SQLite, anything with fsync requirements will corrupt or fail mysteriously.
   Run DBs in Docker directly on the NAS.

2. **One writer per path.** Two allocs on two nodes writing to the same
   path over SMB will fight. Single-instance jobs are fine; if you need
   horizontal scale, design the data layout so each instance writes to its
   own subdirectory.

3. **World-writable.** Everything under the share is `0666`/`0777` so
   containers running as any UID can read/write. Isolation between jobs is
   organisational (one subdirectory per job), not enforced by the
   filesystem.

4. **NAS is a SPoF.** If the NAS is down, every job that needs the share
   fails to start (loudly — bind-mount setup fails). Nightly replication
   to a sibling NAS is the recovery story, not live failover.

## Using the share from a job

In a Docker task, add a `mounts` block pointing at a subdirectory of
`/mnt/nas/vault/`:

```hcl
job "grafana" {
  datacenters = ["home"]

  group "grafana" {
    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["http"]

        mounts = [
          {
            type   = "bind"
            source = "/mnt/nas/vault/grafana"
            target = "/var/lib/grafana"
          }
        ]
      }
    }
  }
}
```

That's the whole pattern. The source directory is created on first write;
data persists across allocs and across reschedules to different nodes.

### Conventions

- One top-level subdirectory per job, named after the job
  (`/mnt/nas/vault/<jobname>/`). If a job has multiple persistent paths,
  nest them: `/mnt/nas/vault/grafana/data`, `/mnt/nas/vault/grafana/plugins`.
- Don't bind-mount `/mnt/nas/vault` itself into a container — that exposes
  every other job's data.
- If a job legitimately needs to read another job's data, prefer copying
  via a sidecar or using an API; don't cross-mount.

## Verifying the share on a node

After a switch, on any client:

```sh
sudo ls /mnt/nas/vault
```

First access triggers the automount. If you see a directory listing (or an
empty directory), the share is up. If you get an I/O error or hang past 30
seconds, check:

```sh
systemctl status mnt-nas-vault.automount
journalctl -u mnt-nas-vault.mount
```

Common failure modes:

- Wrong credentials — `journalctl` shows `cifs: VFS: ...status STATUS_LOGON_FAILURE`.
- NAS unreachable — `Connection timed out` or `Host is down`.
- Decryption failure for the credentials secret — check
  `journalctl -u sops-nix.service`; see [sops-nix.md](./sops-nix.md).

## Adding a second share later

To add another SMB share (e.g. a share from a different NAS), duplicate the
`fileSystems` entry in `services/storage/nas/default.nix`, add a second
`sops.secrets` entry for its credentials, and mount it as a sibling under
`/mnt/nas/` (e.g. `/mnt/nas/<nasname>`). Jobs reference the new path the same
way: `mounts = [{ source = "/mnt/nas/<nasname>/<jobname>", ... }]`.

