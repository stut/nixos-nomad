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
      bind_addr = "{{ GetPrivateInterfaces | include \"network\" \"192.168.192.0/24\" | attr \"address\" }}";
      ports = {
        dns = 8600;
      };
      recursors = [ "1.1.1.1" "1.0.0.1" ];
			encrypt = "CJ0ncDhP92euWlWX5EGv2KqBfSkQzEYjXCKTy+VWk3s=";
			#verify_incoming = true;
			#verify_outgoing = true;
			#verify_server_hostname = true;
			connect = {
				enabled = true;
			};
			ui = false;
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
