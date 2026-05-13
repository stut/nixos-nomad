# Managing secrets with sops-nix

This repo uses [sops-nix](https://github.com/Mic92/sops-nix) to ship encrypted
secrets in-tree and decrypt them on each node at activation time. The current
secret in use is the SMB credentials for the NAS share that Nomad jobs
bind-mount data from.

This document covers everything you need to operate it. If you've never used
sops before, read this top to bottom once before touching anything.

## How it's wired up here

- `.sops.yaml` at the repo root lists the age public keys allowed to decrypt
  secrets, and a `creation_rules` block that encrypts anything under
  `secrets/*.yaml` to those keys.
- `secrets/smb.yaml` contains the encrypted SMB credentials. The file is
  committed to git in its encrypted form — that's the whole point.
- `services/storage/nas/default.nix` declares `sops.secrets."smb_credentials"`,
  which at activation time decrypts the value from `secrets/smb.yaml` and
  writes it to `/run/secrets/smb_credentials` (mode `0400`, owned by `root`).
- The CIFS mount references `credentials=/run/secrets/smb_credentials`.
- Decryption uses each host's SSH ed25519 host key as its age identity (via
  `age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]`). No extra key
  material to distribute — the host already has the only key it needs.

## One-time setup on your workstation

You need two tools and one personal age key.

### 1. Install tooling

On macOS, `sops` and `age` are in Homebrew, but `ssh-to-age` is not — install
it via Go:

```sh
brew install sops age
go install github.com/Mic92/ssh-to-age/cmd/ssh-to-age@latest
```

That puts the `ssh-to-age` binary in `$(go env GOPATH)/bin` (usually
`~/go/bin`); add that to your `$PATH` if it isn't already. If you don't have
Go installed, `brew install go` first.

Alternatively, if you have nix on macOS you can avoid the Go step:

```sh
nix-shell -p sops age ssh-to-age
```

On NixOS:

```sh
nix-shell -p sops age ssh-to-age
```

### 2. Generate your personal age key

```sh
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

The file contains both your private and public key. Note the public key
(starts with `age1...`). **Back this file up somewhere safe** — if you lose
it, you lose the ability to decrypt secrets from your workstation. (The hosts
can still decrypt with their own keys, so the cluster keeps working; you just
won't be able to edit secrets until you re-add a new personal key.)

`sops` finds your private key automatically by reading
`~/.config/sops/age/keys.txt`. If you put it elsewhere, set
`SOPS_AGE_KEY_FILE` to point at it.

### 3. Put your personal age public key in `.sops.yaml`

Edit `.sops.yaml` in the repo root and replace the `&admin` placeholder with
your public key.

## Bootstrapping a brand-new node

This is the **two-step dance**. The host needs an SSH ed25519 host key to
exist before sops-nix can decrypt anything for it, but that key only comes
into being on the first `nixos-rebuild switch`. So:

### Step 1 — first switch (generates the host key)

Install NixOS, clone this repo to `/home/admin/nixos-nomad`, then:

```sh
./apply.sh switch <type>
```

This will fail at the point where it tries to decrypt the SMB credentials,
because the new host's age key isn't in `.sops.yaml` yet. That's expected.
The host's SSH key has now been generated, which is all we need.

If the build aborts before activation (the sops-nix module checks secrets at
build time on some configurations), you can temporarily comment out the
`storage/nas` import in `node-types/client/default.nix`, switch, and then
uncomment it after step 2.

### Step 2 — add the host's age key and re-encrypt

From your workstation (or the server, anywhere you have a clone with sops
available):

```sh
# Pull the new host's SSH public key
ssh -p 64242 admin@<new-node-ip> sudo cat /etc/ssh/ssh_host_ed25519_key.pub \
  | ssh-to-age
```

Copy the resulting `age1...` line. Edit `.sops.yaml`, add it as a new entry
under `keys:` with a descriptive anchor (e.g. `&host_client3`), and reference
it in the `creation_rules` `age:` list.

Then re-encrypt all secrets so the new host can decrypt them:

```sh
sops updatekeys secrets/smb.yaml
```

Commit the changes to `.sops.yaml` and `secrets/smb.yaml`.

### Step 3 — second switch

On the new node, pull the updated repo and run `./apply.sh switch <type>`
again. This time decryption succeeds, `/run/secrets/smb_credentials` appears,
and the CIFS mount comes up.

## Daily workflow

### Editing the SMB credentials (or any secret)

```sh
sops secrets/smb.yaml
```

This decrypts in memory, drops you into your `$EDITOR`, and re-encrypts on
save. The plaintext never touches disk.

The current schema is one key:

```yaml
smb_credentials: |
  username=nomad
  password=hunter2
```

The `|` is important — it preserves the newline so the file is valid as a
cifs credentials file when written to `/run/secrets/smb_credentials`.

### Rotating the SMB password

1. Change the password for the SMB user on the NAS.
2. `sops secrets/smb.yaml` and update the `password=` line.
3. Commit and push.
4. On each node: `./apply.sh switch <type>` (or wait for whatever automation
   you've wired up). On activation sops-nix re-renders
   `/run/secrets/smb_credentials`, but the existing CIFS mount holds the old
   password until remounted. To force a remount:
   ```sh
   sudo systemctl restart mnt-nas-vault.automount
   ```

### Adding a new secret

1. Add the value:
   ```sh
   sops secrets/smb.yaml          # or a new file like secrets/foo.yaml
   ```
   Add a new key, save.
2. Reference it in NixOS:
   ```nix
   sops.secrets."my_new_secret" = {
     sopsFile = ../../../secrets/foo.yaml;   # only if it's a new file
     mode = "0400";
   };
   ```
3. Switch.

### Removing a host (decommissioning)

1. Remove the host's anchor from `.sops.yaml`'s `keys:` list and from each
   `creation_rules` group that referenced it.
2. `sops updatekeys secrets/*.yaml` to re-encrypt without that key.
3. Commit.

The decommissioned host's old encrypted secrets are still readable by its
key if anyone has a copy of the old git history — rotate any secret that
matters if the host left under untrustworthy circumstances.

## Troubleshooting

**`sops: Failed to get the data key required to decrypt the SOPS file`**
This host's age key isn't in `.sops.yaml`, or you forgot to run
`sops updatekeys` after adding it. Re-check both.

**`Failed to decrypt with key [age1...]: no identity matched any of the recipients`**
Your local `~/.config/sops/age/keys.txt` doesn't contain a private key that
matches any recipient on the file. Likely you're on a different workstation,
or the file isn't where sops expects.

**Mount works but contains stale credentials after a rotation**
The CIFS automount caches the credentials of its last successful mount.
Restart the automount unit (see "Rotating the SMB password" above).

**Build error: `path '/run/secrets/smb_credentials' does not exist`**
First boot before sops-nix has run. If this is a fresh node, follow the
two-step bootstrap. If not, check `systemctl status sops-nix.service` for
the actual decryption failure.
