{ inputs, outputs, lib, pkgs, clusterConfig, ... }: {
  imports = [
  ];

  i18n.defaultLocale = lib.mkDefault "en_GB.UTF-8";
  time.timeZone = lib.mkDefault "Europe/London";

  nix = {
    settings = {
      system-features = [
        "kvm"
        "big-parallel"
        "nixos-test"
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      flake-registry = "";
    };
  
    nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];

    registry = lib.mapAttrs (_: value: {
      flake = value;
    }) inputs;
  
    gc = {
      automatic = true;
      dates = "weekly";
      randomizedDelaySec = "1h";
      options = "--delete-older-than 30d";
    };
  };

  services = {
    openssh = {
      enable = true;
      ports = [ clusterConfig.sshPort ];
      hostKeys = [{
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }];
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        ChallengeResponseAuthentication = "no";
        X11Forwarding = false;
        PrintMotd = "no";
      };
    };
  };
  
  security.sudo = {
    execWheelOnly = true;
    wheelNeedsPassword = false;
  };

  hardware.enableRedistributableFirmware = true;
  
  networking = {
    enableIPv6 = false;
    # Disable the firewall for the moment
    firewall = {
			enable = false;
			allowedTCPPorts = [ 22 80 443 ];
			allowedUDPPorts = [ 53 ];
		};
    nameservers = [ "1.1.1.1" "1.0.0.1" "8.8.8.8" ];
    # Set the hostname using DHCP
    hostName = "";
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    vim
  ];

  users = {
    mutableUsers = false;
    users = {
      admin = {
        isNormalUser = true;
        shell = pkgs.bash;
        extraGroups = [ "wheel" "network" ];
        openssh = {
          authorizedKeys = {
            keys = clusterConfig.sshPublicKeys;
          };
        };
      };
    };
  };

  system.stateVersion = "23.11";
}
