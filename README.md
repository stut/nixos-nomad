# nixos-nomad

Add your `hardware-configuration.nix` and this will give you a hopefully
working, single-node Consul and Nomad environment.

You should also be able to take `consul.nix` and `nomad.nix` and add them
to an existing nix configuration.

Note that security is currently non-existent in this setup so it's intended
for local use only.

Once applied head to `http://[host-ip]:8500/` for Consul,
`http://[host-ip]:4646/` for Nomad. If you're on the host itself you can run
`damon` to see a TUI for Nomad.
