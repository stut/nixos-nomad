# nixos-nomad

This is a NixOS configuration for running Consul and Nomad in your home lab.
It's intended for development and testing purposes only as there is no
consideration for security (yet). It's also very much a work in progress.

It currently supports building a single-node Consul and Nomad environment,
as well as a cluster with a single server node and one or more clients. Note
that the cluster setup is the only one that has been well-tested so far as
that's what I'm running.

## Hosts

Rather than specifying individual hosts in the configuration, the flake
supports three types of configuration that can be applied to individual nodes:
`server`, `client`, and `hybrid`.

Hostnames are set by DHCP by default, so I have my home router set up with
static IPs and hostnames for each machine. With this setup I can add and remove
clients without needing to change the configuration. Consul is configured to
leave the cluster, and Nomad to drain the node, on a graceful shutdown. Manual
intervention is required if a node is removed without a graceful shutdown.

If you'd prefer to specify the hostnames in the flake, you can do that by
modifying the `nixosConfigurations` section in `flake.nix`.

## Usage

### 0. Fork and customise this repo

You'll want to fork this repo before using it, unless your IP range and public
SSH key happen to match mine.

Edit `flake.nix` at the top of the output section to customise the datacenter
name, server IP, SSH port, and to add your public SSH key(s).

Then, for each machine:

### 1. Install NixOS

It's best to use the manual installation method but you can use the graphical
installer if you prefer. Install as minimal a system as possible, you just
need to ensure that networking is setup and you can SSH to the machine.

The flake will create a user called admin so it's best to use the same username
when installing NixOS. You can change this in the flake if you prefer.

If you're setting up a cluster, make sure you setup the server first.

### 2. Clone/copy your fork

I like to put it in `/home/admin/nixos-nomad` but you can put it wherever your
heart desires.

### 3. Apply the configuration

The repo contains a script called `apply.sh` which encapsulates the command to
apply the configuration. You can run it like so:

```sh
./apply.sh <operation> <type>
```

Where `operation` is one of:

- `switch`: applies the configuration immediately
- `boot`: builds the configuration so it's applied when rebooted

Yes, these are passed directly to the `nixos-rebuild` command.

And `type` is one of:

- `server`
- `client`
- `hybrid`

## What about the hardware config?

By default the `apply.sh` script will use the `hardware-configuration.nix` file
created by the installer. If you need to customise it you should edit
`/etc/nixos/hardware-configuration.nix`.

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

### Firewalls

Firewalls are disabled on all nodes by default.

### SSH

In theory the only reason to access any of the nodes via SSH is to pull and
apply changes to the configuration. The shell is `bash` and `vim` is installed
by default. These can be changed in `node-types/common/default.nix`. If you
change the shell you may need to modify `apply.sh`.

## TODO

These are in no particular order, and none are necessary to get a working
system.

- [ ] Add a basic `configuration.nix` to be used when installing NixOS
- [ ] Add a default set of infra jobs to run on the cluster (e.g. Prometheus,
      Grafana, Traefik, etc.)
- [ ] Add a systemd timer to pull and apply the configuration automatically
- [ ] Enable the firewall on all nodes without breaking things
- [ ] Enable encryption for Consul and Nomad gossip
- [ ] Add support for Vault

## Disclaimer

This repo is not fit for any purpose, and your use of it is entirely at your
own risk. If you do use it, you agree to hold me harmless for any damage it
causes. You should also be aware that the software it installs is licensed
under various licenses, and you are responsible for complying with those.

If you improve it, or have any requests/suggestions, please feel free to open
an issue or PR.
