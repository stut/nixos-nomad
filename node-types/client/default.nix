{ inputs, hostname, ... }: {
  imports = [
    ../../hardware-configuration.nix
    ../common

    ../../services/consul/client
    ../../services/nomad/client
  ];
}
