{ lib, pkgs, clusterConfig, ... }:
{
  services.consul = {
    enable = true;
    package = pkgs.consul;

    extraConfig = {
      datacenter = clusterConfig.datacenterName;
      log_level = "INFO";
      server = false;
      retry_join = [clusterConfig.serverIp];
      leave_on_terminate = true;
      bind_addr = "{{ GetPrivateIP }}";
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
