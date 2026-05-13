# Migrating an existing cluster to the auto-upgrade layout

This is a one-time procedure. Once every node is migrated, delete this file.

The new layout puts the repo at `/etc/nixos/` (root-owned, git checkout
of `origin/main`) and identifies each node via `/etc/nixos/node.json`. The
old `~admin/nixos-nomad/` directory is no longer the source of truth and
can be removed afterwards.

Do the **server first**, then each client in order.

## Per-node steps

SSH to the node. Then:

1. Drain cleanly. Stopping the services triggers the existing graceful
   shutdown hooks (Nomad drains, Consul leaves):

   ```sh
   sudo systemctl stop nomad consul
   ```

   Wait until allocations have moved off (`nomad node status` from another
   node if it's a client; instant on the server).

2. Back up the hardware config and clear `/etc/nixos`:

   ```sh
   sudo cp /etc/nixos/hardware-configuration.nix /tmp/hardware-configuration.nix
   sudo rm -rf /etc/nixos
   ```

3. Clone the repo into `/etc/nixos` and restore the hardware config:

   ```sh
   sudo git clone https://github.com/stut/nixos-nomad /etc/nixos
   sudo cp /tmp/hardware-configuration.nix /etc/nixos/hardware-configuration.nix
   ```

4. Write `node.json`. `role` is `server`, `client`, or `hybrid`. `ordinal`
   distinguishes clients for staggered upgrade times (server/hybrid: any
   value, conventionally 0; client N: schedules upgrade at `(2+N):00`).

   ```sh
   sudo tee /etc/nixos/node.json > /dev/null <<'JSON'
   { "role": "client", "ordinal": 1 }
   JSON
   ```

5. First apply (this also installs the auto-upgrade timer):

   ```sh
   cd /etc/nixos
   sudo nixos-rebuild switch --flake path:.#auto
   ```

6. Confirm the timer is armed:

   ```sh
   systemctl list-timers nixos-upgrade.timer
   systemctl is-enabled nixos-upgrade.service   # should be: enabled
   ```

7. Bring services back up if they didn't restart from the rebuild:

   ```sh
   sudo systemctl start consul nomad
   ```

8. Clean up the old checkout:

   ```sh
   rm -rf ~admin/nixos-nomad ~admin/nixos-config
   ```

## After all nodes are migrated

- Delete this file.
- Tick the auto-upgrade item off the README TODO list.
