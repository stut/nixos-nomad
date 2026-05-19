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

  slackNotify = "/etc/nixos-nomad/slack-notify";
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
      # Stash per-host files across `git reset --hard`. They're gitignored
      # *and* intent-to-add (see below), and reset --hard deletes any path
      # present in the index — so without this they'd be wiped each run.
      install -d -m 0700 /var/lib/nixos-nomad/host-files
      cp -f hardware-configuration.nix /var/lib/nixos-nomad/host-files/
      cp -f node.json                  /var/lib/nixos-nomad/host-files/

      git fetch origin main
      git reset --hard origin/main

      cp -f /var/lib/nixos-nomad/host-files/hardware-configuration.nix .
      cp -f /var/lib/nixos-nomad/host-files/node.json                  .

      # /etc/nixos is a git repo, so `path:` flake ingest filters by
      # gitignore. Mark the restored files intent-to-add so the flake
      # source copy includes them without actually committing.
      git add --intent-to-add --force hardware-configuration.nix node.json
    '';
    unitConfig.OnFailure = [ "nixos-upgrade-failure.service" ];
    # On success: clear the failure marker, then if the new system needs a
    # reboot, post a 'rebooting' Slack message and drop a marker that the
    # post-boot unit will use to confirm the host came back.
    serviceConfig.ExecStartPost = pkgs.writeShellScript "nixos-upgrade-post" ''
      set -u
      rm -f /var/lib/nixos-nomad/last-upgrade-failed

      booted="$(readlink -f /run/booted-system 2>/dev/null || true)"
      current="$(readlink -f /run/current-system 2>/dev/null || true)"
      if [ -n "$booted" ] && [ -n "$current" ] && [ "$booted" != "$current" ]; then
        mkdir -p /var/lib/nixos-nomad
        date -Is > /var/lib/nixos-nomad/pending-reboot-notify
        ${slackNotify} \
          --title "Rebooting after auto-upgrade" \
          --level warn \
          --body "Booted system differs from new system; allowReboot will reboot shortly." \
          || true
      fi
    '';
  };

  systemd.services.nixos-upgrade-failure = {
    description = "Record nixos-upgrade failure for visibility on login";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "record-upgrade-failure" ''
        set -u
        mkdir -p /var/lib/nixos-nomad
        date -Is > /var/lib/nixos-nomad/last-upgrade-failed

        ${pkgs.systemd}/bin/journalctl -u nixos-upgrade -n 20 --no-pager \
          | ${slackNotify} \
              --title "Auto-upgrade failed" \
              --level error \
              --body-stdin \
          || true
      '';
    };
  };

  # After an upgrade-driven reboot, confirm the host is back. Marker is
  # written by nixos-upgrade's ExecStartPost just before the reboot.
  systemd.services.nixos-upgrade-reboot-notify = {
    description = "Notify Slack after a reboot triggered by auto-upgrade";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "nixos-upgrade-reboot-notify" ''
        set -u
        marker=/var/lib/nixos-nomad/pending-reboot-notify
        if [ ! -e "$marker" ]; then
          exit 0
        fi
        ${slackNotify} \
          --title "Back up after auto-upgrade" \
          --level info \
          --body "Host has returned after the auto-upgrade reboot." \
          || true
        rm -f "$marker"
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
