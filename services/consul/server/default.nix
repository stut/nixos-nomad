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

      #encrypt = "";
      #ca_file = "";
      #cert_file = "";
      #key_file = "";
      #verify_incoming = true;
      #verify_outgoing = true;
      #verify_server_hostname = true;

      connect = {
        enabled = true;
      };

      ports = {
        grpc = 8502;
      };

      acl = {
        enabled = false;
      };
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
