# nixos-nomad

Add your `hardware-configuration.nix` and this will give you a hopefully
working, single-node `consul` and `nomad` environment.

You should also be able to take `consul.nix` and `nomad.nix` and add them
to an existing nix configuration.

Note that security is currently non-existent in this setup so it's intended
for local use only.

