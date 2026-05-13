{ pkgs, lib, nodeConfig, ... }:
let
  # Schedule:
  #   server / hybrid -> 02:00
  #   client ordinal N -> (02 + N):00, e.g. ordinal 1 -> 03:00
  # randomizedDelaySec=45min lets nodes with the same ordinal still spread out.
  hour =
    if nodeConfig.role == "client"
    then 2 + nodeConfig.ordinal
    else 2;
  hourStr =
    if hour < 10
    then "0${toString hour}"
    else toString hour;
  schedule = "${hourStr}:00";
in
{
  system.autoUpgrade = {
    enable = true;
    flake = "path:/etc/nixos#auto";
    operation = "switch";
    allowReboot = true;
    dates = schedule;
    randomizedDelaySec = "45min";
  };

  # Pull origin/main into /etc/nixos before each upgrade. /etc/nixos is a
  # checkout owned by root; gitignored files (hardware-configuration.nix,
  # node.json) survive `git reset --hard`.
  systemd.services.nixos-upgrade = {
    path = [ pkgs.git ];
    preStart = ''
      cd /etc/nixos
      git fetch origin main
      git reset --hard origin/main
    '';
    unitConfig.OnFailure = [ "nixos-upgrade-failure.service" ];
  };

  systemd.services.nixos-upgrade-failure = {
    description = "Record nixos-upgrade failure for visibility on login";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "record-upgrade-failure" ''
        mkdir -p /var/lib/nixos-nomad
        date -Is > /var/lib/nixos-nomad/last-upgrade-failed
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/nixos-nomad 0755 root root - -"
  ];

  # Surface dev-mode and failure state on shell login.
  environment.shellInit = ''
    if [ -e /var/lib/nixos-nomad/dev-mode ]; then
      echo ""
      echo "*** DEV MODE: auto-upgrade is masked on this cluster ***"
      echo ""
    fi
    if [ -e /var/lib/nixos-nomad/last-upgrade-failed ]; then
      echo ""
      echo "*** Last auto-upgrade FAILED at $(cat /var/lib/nixos-nomad/last-upgrade-failed)"
      echo "*** See: journalctl -u nixos-upgrade"
      echo ""
    fi
  '';
}
