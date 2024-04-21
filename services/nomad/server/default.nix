{ lib, pkgs, clusterConfig, ... }:
{
  nixpkgs.config.allowUnfree = true;

  services.nomad = {
    enable = true;
    package = pkgs.nomad;

    # Nomad configuration, as Nix attribute set.
    settings = {
      bind_addr = "0.0.0.0";
      datacenter = clusterConfig.datacenterName;
      
      server = {
        enabled = true;
        bootstrap_expect = 1;
      };

      client = {
        enabled = false;
      };
      
      consul = {
        address = "127.0.0.1:8500";
      };

      acl = {
        enabled = false;
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
