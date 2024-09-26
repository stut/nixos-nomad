{ lib, pkgs, clusterConfig, ... }:
{
  nixpkgs.config.allowUnfree = true;

  services.nomad = {
    enable = true;
    package = pkgs.nomad;

    # Add Docker driver.
    enableDocker = true;
    # Add extra plugins to Nomads plugin directory.
    extraSettingsPlugins = [ ];

    # Nomad as Root to access Docker sockets.
    dropPrivileges = false;

    # Nomad configuration, as Nix attribute set.
    settings = {
      bind_addr = "0.0.0.0";
      advertise = {
        http = "{{ GetPrivateInterfaces | include \"network\" \"192.168.192.0/24\" | attr \"address\" }}";
      };
      datacenter = clusterConfig.datacenterName;
      leave_on_interrupt = true;
      leave_on_terminate = true;
      
      server = {
        enabled = false;
      };
      
      client = {
        enabled = true;
        servers = [clusterConfig.serverIp];
        drain_on_shutdown = {
          deadline           = "5m";
          force              = false;
          ignore_system_jobs = false;
        };
				artifact = {
          disable_filesystem_isolation = true;
        };
      };
      
      plugin = {
        raw_exec = {
          enable = true;
        };

        docker = {
          config = {
            allow_privileged = true;
          };
        };
      };
      
      consul = {
        address = "127.0.0.1:8500";
      };

      acl = {
        enabled = false;
      };
    };
  };

  virtualisation = {
    docker = {
      enable = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 4646 4647 4648  ];
  networking.firewall.allowedUDPPorts = [ 4648 ];
  
  systemd.services.nomad = {
    after = [ "network.target" ];
    serviceConfig = {
      Restart = lib.mkForce "always";
    };
  };
}
