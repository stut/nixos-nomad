{ pkgs, ... }:
{
  sops = {
    defaultSopsFile = ../../secrets/slack.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets."slack_webhook_url" = {
      mode = "0400";
      owner = "root";
      group = "root";
    };
  };

  environment.etc."nixos-nomad/slack-notify" = {
    mode = "0700";
    user = "root";
    group = "root";
    text = ''
      #!${pkgs.bash}/bin/bash
      set -u
      set -o pipefail

      log() { ${pkgs.systemd}/bin/systemd-cat -t slack-notify -p info echo "$1" 2>/dev/null || echo "slack-notify: $1" >&2; }

      title=""
      body=""
      body_stdin=0
      level="info"

      while [ $# -gt 0 ]; do
        case "$1" in
          --title)      title="$2"; shift 2 ;;
          --body)       body="$2"; shift 2 ;;
          --body-stdin) body_stdin=1; shift ;;
          --level)      level="$2"; shift 2 ;;
          *) log "unknown arg: $1"; exit 0 ;;
        esac
      done

      if [ -e /var/lib/nixos-nomad/dev-mode ]; then
        log "dev-mode active, suppressing: $title"
        exit 0
      fi

      if [ ! -r /run/secrets/slack_webhook_url ]; then
        log "webhook not configured, suppressing: $title"
        exit 0
      fi

      if [ "$body_stdin" -eq 1 ]; then
        body="$(cat)"
      fi

      # Trim body to ~2.5KB to stay under Slack limits.
      max=2500
      if [ "''${#body}" -gt "$max" ]; then
        body="''${body:0:$max}

[truncated]"
      fi

      case "$level" in
        info)  color="good" ;;
        warn)  color="warning" ;;
        error) color="danger" ;;
        *)     color="#cccccc" ;;
      esac

      host="$(${pkgs.nettools}/bin/hostname -s)"
      full_title="[$host] $title"

      webhook="$(cat /run/secrets/slack_webhook_url)"

      payload="$(${pkgs.jq}/bin/jq -n \
        --arg channel "#stut-cloud" \
        --arg color "$color" \
        --arg title "$full_title" \
        --arg text  "$body" \
        '{channel: $channel, attachments: [{color: $color, title: $title, text: $text}]}')"

      if ! ${pkgs.curl}/bin/curl \
            --silent --show-error \
            --max-time 10 --retry 2 \
            -H 'Content-Type: application/json' \
            -d "$payload" \
            "$webhook" >/dev/null 2>&1; then
        log "curl failed posting to Slack: $full_title"
      fi

      exit 0
    '';
  };
}
