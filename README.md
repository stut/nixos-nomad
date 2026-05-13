# nixos-nomad

This is a NixOS configuration for running Consul and Nomad in your home lab.
It's intended for development and testing purposes only as there is no
consideration for security (yet). It's also very much a work in progress.

It currently supports building a single-node Consul and Nomad environment,
as well as a cluster with a single server node and one or more clients. Note
that the cluster setup is the only one that has been well-tested so far as
that's what I'm running.

> **Fork this repo before using it — do not deploy directly from upstream.**
> The configuration hardcodes my IP range, SSH public keys, SSH port, NAS
> address, and host aliases (`s01`, `c01`, `c02`, `c03`). Every node also
> auto-updates from `origin/main` of whatever fork it was cloned from, so
> a node pointed at this upstream repo will pull *my* changes on its own
> schedule. Fork first, point your nodes at your fork.

## Hosts

Rather than specifying individual hosts in the configuration, the flake
supports three types of configuration that can be applied to individual nodes:
`server`, `client`, and `hybrid`.

Hostnames are set by DHCP by default, so I have my home router set up with
static IPs and hostnames for each machine. With this setup I can add and remove
clients without needing to change the configuration. Consul is configured to
leave the cluster, and Nomad to drain the node, on a graceful shutdown. Manual
intervention is required if a node is removed without a graceful shutdown.

Each node identifies itself via `/etc/nixos/node.json` (gitignored,
populated at install time):

```json
{ "role": "client", "ordinal": 1 }
```

`role` is `server`, `client`, or `hybrid`. `ordinal` distinguishes clients
for the staggered auto-upgrade schedule (see below).

## Usage

### 0. Fork and customise this repo

Edit `flake.nix` at the top of the output section to customise the datacenter
name, server IP, SSH port, and to add your public SSH key(s).

If you want persistent storage for jobs via an SMB share on a NAS, configure
the `nas` block in the same section (host, share name, mount point). Set
`nas.enable = false` to skip it entirely — the clients will then come up
without `cifs-utils` and without a credentials secret. See
[`docs/smb-storage.md`](docs/smb-storage.md) for the model and
[`docs/sops-nix.md`](docs/sops-nix.md) for credential management.

Then, for each machine:

### 1. Install NixOS

It's best to use the manual installation method but you can use the graphical
installer if you prefer. Install as minimal a system as possible, you just
need to ensure that networking is setup and you can SSH to the machine.

The flake will create a user called admin so it's best to use the same username
when installing NixOS. You can change this in the flake if you prefer.

If you're setting up a cluster, make sure you setup the server first.

### 2. Bootstrap `/etc/nixos`

The repo lives at `/etc/nixos` as a root-owned git checkout. Preserve the
installer-generated `hardware-configuration.nix`, clone your fork, then
write `node.json`:

```sh
sudo cp /etc/nixos/hardware-configuration.nix /tmp/
sudo rm -rf /etc/nixos
sudo git clone https://github.com/<you>/nixos-nomad /etc/nixos
sudo cp /tmp/hardware-configuration.nix /etc/nixos/
sudo $EDITOR /etc/nixos/node.json   # write { "role": "...", "ordinal": N }
```

### 3. Apply the configuration

```sh
cd /etc/nixos
sudo nixos-rebuild switch --flake path:.#auto
```

After this first apply the auto-upgrade timer is armed and the node will
pull `origin/main` and rebuild on its schedule.

## Auto-upgrade

Every node runs a systemd timer that pulls `origin/main` into `/etc/nixos`
and runs `nixos-rebuild switch`. Schedule is derived from `node.json`:

- `server` / `hybrid` → 02:00
- `client` ordinal N → `(2 + N):00` (e.g. ordinal 1 → 03:00, ordinal 2 → 04:00)

All nodes have a 45-minute randomised delay on top. Setting every client to
the same ordinal collapses the schedule to "everyone fires in a random
45-minute window after 03:00."

`allowReboot` is on, so kernel updates trigger a reboot. The existing
Consul/Nomad graceful-shutdown hooks drain the node first.

### Manually triggering an upgrade

```sh
./trigger-auto-upgrade.sh              # all hosts
./trigger-auto-upgrade.sh c02 c03      # named hosts
```

### Failure visibility

A failed auto-upgrade leaves `nixos-upgrade.service` in the systemd `failed`
state (visible to `node_exporter`'s systemd collector once you wire up
monitoring) and writes a timestamp to `/var/lib/nixos-nomad/last-upgrade-failed`,
which is surfaced on shell login until the next successful run.

## Dev mode (testing uncommitted changes)

The auto-upgrade timer would clobber an `scp`'d working tree, so testing
uncommitted changes requires disabling it cluster-wide first:

```sh
./dev-mode-on.sh        # masks nixos-upgrade.service on every node
./apply-remote.sh       # scps the working tree and applies to each node
# ... iterate, test ...
./dev-mode-off.sh       # re-enables the timer
```

`apply-remote.sh` hard-refuses to run unless every target is masked, so you
can't forget the first step. While dev mode is on, every shell login on a
node shows a warning so you don't forget the third step.

`apply-remote.sh` assumes:

- SSH host aliases `s01`, `c01`, `c02`, `c03` in your `~/.ssh/config`. Edit
  the host list at the top of the script if your topology differs.
- The remote `admin` user can `sudo nixos-rebuild` without a password,
  which is the default in this repo's common config.

The server is switched first, then the clients in order. If a step fails
the script aborts (`set -e`).

## What about the hardware config?

`hardware-configuration.nix` lives at `/etc/nixos/hardware-configuration.nix`
and is gitignored, so it's never carried between machines and survives
the auto-upgrade `git reset --hard`. `switch.sh` (used in dev mode) copies
it into the dev tree before each rebuild.

## Post-installation

Once applied head to `http://[server-ip]:8500/` for Consul,
`http://[server-ip]:4646/` for Nomad. If you're logged in to any of the
machines you can run `damon` to see a TUI for Nomad.

## Configuration notes

### Passwords

No passwords are set for either the `root` or `admin` users. There should be
very few reasons to access the client nodes directly as they should be
considered ephemeral, but you should set passwords for both users on the
server. If you don't you won't be able to log into the machine on its console
in the case of network issues.

Users in the `wheel` group, i.e. `admin`, can `sudo` without a password. If
you change this you'll need to add a password to the config.

### Firewalls

Firewalls are disabled on all nodes by default.

### SSH

In theory, the only reason to access any of the nodes via SSH is to inspect
state or recover from a failed auto-upgrade. The shell is `bash`, and `vim`
is installed by default. These can be changed in `node-types/common/default.nix`.

## TODO

These are in no particular order, and none are necessary to get a working
system.

- [ ] Add a workstation-side `bootstrap.sh` that sets up a fresh node end-to-end
      (subsumes the older "basic `configuration.nix` for installing NixOS" idea)
- [ ] Add a default set of infra jobs to run on the cluster (e.g. Prometheus,
      Grafana, Traefik, etc.)
- [ ] Active failure notification for auto-upgrade (email / ntfy / Slack)
- [ ] Enable the firewall on all nodes without breaking things
- [ ] Enable encryption for Consul and Nomad gossip
- [ ] Add support for Vault

## Disclaimer

This repo is not fit for any purpose, and your use of it is entirely at your
own risk. If you do use it, you agree to hold me harmless for any damage it
causes. You should also be aware that the software it installs is licensed
under various licenses, and you are responsible for complying with those.

If you improve it or have any requests/suggestions, please feel free to open
an issue or PR.
