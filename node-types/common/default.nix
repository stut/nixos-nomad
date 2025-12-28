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
        PrintMotd = false;
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
			allowedTCPPorts = [ 22 80 443 64242 ];
			allowedUDPPorts = [ 53 ];
		};
		# TODO: Use consul for DNS resolution
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
    # Set the hostname using DHCP
    hostName = "";
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    kernel.sysctl = {
      "net.core.rmem_max" = 2500000;
      "net.core.rmem_default" = 2500000;
      "net.core.wmem_max" = 2500000;
      "net.core.wmem_default" = 2500000;
    };
  };

  environment.systemPackages = with pkgs; [
    curl
		dig
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

  system.stateVersion = "24.05";
}
