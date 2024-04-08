{ lib, pkgs, ... }:
{
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
      datacenter = "your-datacentre";
      
      client = {
        enabled = true;
      };
      
      server = {
        enabled = true;
        bootstrap_expect = 1;
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
    docker.enable = true;
  };

  networking.firewall.allowedTCPPorts = [ 4646 4647 4648  ];
  networking.firewall.allowedUDPPorts = [ 4648 ];

  environment.systemPackages = with pkgs; [
    damon
  ];
}

