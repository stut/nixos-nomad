{ lib, pkgs, clusterConfig, ... }:
let
  cfg = clusterConfig.nas or { enable = false; };
  mountParent = builtins.dirOf cfg.mountPoint;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ cifs-utils ];

    sops = {
      defaultSopsFile = ../../../secrets/smb.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets."smb_credentials" = {
        mode = "0400";
        owner = "root";
        group = "root";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${mountParent} 0755 root root -"
    ];

    fileSystems.${cfg.mountPoint} = {
      device = "//${cfg.host}/${cfg.share}";
      fsType = "cifs";
      options = [
        "credentials=/run/secrets/smb_credentials"
        "vers=3.0"
        "uid=0"
        "gid=0"
        "file_mode=0666"
        "dir_mode=0777"
        "nobrl"
        "noatime"
        "_netdev"
        "x-systemd.automount"
        "x-systemd.mount-timeout=30"
        "x-systemd.idle-timeout=600"
      ];
    };
  };
}
