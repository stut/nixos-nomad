#!/bin/sh
# Push the working tree to every node and apply it (dev-mode flow).
#
# Refuses to run unless every target is in dev mode (auto-upgrade masked),
# to avoid racing with the timer.

set -e

HOSTS="s01 c01 c02 c03"
SERVER="s01"

for host in $HOSTS; do
    state=$(ssh "$host" "systemctl is-enabled nixos-upgrade.service 2>/dev/null || true")
    if [ "$state" != "masked" ]; then
        echo "error: $host is not in dev mode (nixos-upgrade.service: ${state:-unknown})"
        echo "run ./dev-mode-on.sh first"
        exit 1
    fi
done

for host in $HOSTS; do
    scp -r * .sops.yaml "${host}:nixos-config/"
done

echo
echo "--------------------------------"
echo
echo "$SERVER"
ssh "$SERVER" "cd nixos-config && ./switch.sh"

for host in $HOSTS; do
    [ "$host" = "$SERVER" ] && continue
    echo
    echo "--------------------------------"
    echo
    echo "$host"
    ssh "$host" "cd nixos-config && ./switch.sh"
done
