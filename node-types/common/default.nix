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
			enable = true;
			# Enabling port 53 for my home lab only; should probably be closed for publicly exposed servers!
			allowedTCPPorts = [ 22 53 80 443 64242 ];
			allowedUDPPorts = [ 53 ];
			# Consul does not run as root, but we want it to respond to DNS requests on port 53, so we'll forward it
			# to a higher port
			extraCommands = ''
				iptables -t nat -A PREROUTING -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600
				iptables -t nat -A PREROUTING -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600
				iptables -t nat -A OUTPUT -d localhost -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600
				iptables -t nat -A OUTPUT -d localhost -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600
			'';
		};
		# Use consul for DNS resolution
    nameservers = [ "127.0.0.1" "1.1.1.1" "1.0.0.1" ];
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
