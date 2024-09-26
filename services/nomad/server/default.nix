{ lib, pkgs, clusterConfig, ... }:
{
  nixpkgs.config.allowUnfree = true;

  services.nomad = {
    enable = true;
    package = pkgs.nomad;

    extraPackages = with pkgs; [
      cni-plugins
    ];

    # Nomad configuration, as Nix attribute set.
    settings = {
      bind_addr = "0.0.0.0";
      datacenter = clusterConfig.datacenterName;
      
      server = {
        enabled = true;
        bootstrap_expect = 1;
				encrypt = "Q8kjhnRbGlCYhKJQcAbJwLBcfESabQ6zs+qUjqpUUy4=";
      };

      client = {
        enabled = false;
        cni_path = "${pkgs.cni-plugins}/bin";
      };
      
      consul = {
        address = "127.0.0.1:8500";
      };

      acl = {
        enabled = false;
      };

			telemetry = {
				collection_interval = "1s";
				disable_hostname = true;
				prometheus_metrics = true;
				publish_allocation_metrics = true;
				publish_node_metrics = true;
			};
    };
  };

  networking.firewall.allowedTCPPorts = [ 4646 4647 4648  ];
  networking.firewall.allowedUDPPorts = [ 4648 ];

  environment.systemPackages = with pkgs; [
    damon
  ];
  
  systemd.services.nomad = {
    after = [ "network.target" ];
    serviceConfig = {
      Restart = lib.mkForce "always";
    };
  };
}
