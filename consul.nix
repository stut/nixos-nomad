{ lib, pkgs, ... }:
{
  services.consul = {
    enable = true;
    package = pkgs.consul;

    extraConfig = {
      server = true;
      ui = true;
      ui_config.enabled = true;
      
      bind_addr = "0.0.0.0";
      client_addr = "0.0.0.0";
      advertise_addr = "192.168.192.131";
      bootstrap_expect = 1;

      datacenter = "your-datacentre";

      #encrypt = "";
      #ca_file = "";
      #cert_file = "";
      #key_file = "";
      #verify_incoming = true;
      #verify_outgoing = true;
      #verify_server_hostname = true;

      service = {
        name = "consul";
      };

      connect = {
        enabled = true;
      };

      ports = {
        grpc = 8502;
      };

      acl = {
        enabled = true;
	default_policy = "allow";
	down_policy = "extend-cache";
	enable_token_persistence = true;
      };

      performance = {
        raft_multiplier = 1;
      };

    };
  };

  networking.firewall.allowedTCPPorts = [ 8500 8501 8502 8503 8600 8300 8301 8302 ];
  networking.firewall.allowedUDPPorts = [ 8600 8300 8301 8302 ];

  systemd.services.consul.serviceConfig.Type = "notify";
}

