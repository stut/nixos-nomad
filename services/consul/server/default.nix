{ lib, pkgs, clusterConfig, ... }:
{
  services.consul = {
    enable = true;
    package = pkgs.consul;

    extraConfig = {
      server = true;
      rejoin_after_leave = true;
      ui = true;
      ui_config.enabled = true;
      
      client_addr = "0.0.0.0";
      advertise_addr = clusterConfig.serverIp;
      bootstrap_expect = 1;

      datacenter = clusterConfig.datacenterName;
      node_name = "server01";

      encrypt = "CJ0ncDhP92euWlWX5EGv2KqBfSkQzEYjXCKTy+VWk3s=";
      #verify_incoming = true;
      #verify_outgoing = true;
      #verify_server_hostname = true;

      connect = {
        enabled = true;
      };

      ports = {
        grpc = 8502;
        dns = 8600;
      };

      recursors = [ "1.1.1.1" "1.0.0.1" "8.8.8.8" ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 8500 8501 8502 8503 8600 8300 8301 8302 ];
  networking.firewall.allowedUDPPorts = [ 8600 8300 8301 8302 ];

  systemd.services.consul = {
    after = [ "network.target" ];
    serviceConfig = {
      Restart = lib.mkForce "always";
    };
  };
}
