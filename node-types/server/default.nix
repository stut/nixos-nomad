{ inputs, hostname, ... }: {
  imports = [
    ../../hardware-configuration.nix
    ../common

    ../../services/consul/server
    ../../services/nomad/server
  ];
}
