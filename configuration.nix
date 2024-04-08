{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./consul.nix
      ./nomad.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "consoleblank=60" ];

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = lib.mkDefault "us";
    useXkbConfig = true;
  };

  users = {
    groups = {
      network = { };
    };
    users = {
      your_username = {
        openssh.authorizedKeys.keys = [
          "your public key"
        ];
        isNormalUser = true;
        extraGroups = [ "wheel" "network" ];
        packages = with pkgs; [];
      };
    };
  };

  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    neovim
    wget
  ];

  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh.enable = true;

  networking = {
    hostName = "your-hostname";
    firewall = {
      enable = true;
    };
  };

  system.copySystemConfiguration = true;
  system.stateVersion = "23.11"; # Do not change!
}

