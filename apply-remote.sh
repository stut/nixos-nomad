#!/bin/sh
# Push the working tree to every node and apply it (dev-mode flow).
#
# Refuses to run unless every target is in dev mode (auto-upgrade timer
# stopped + dev-mode marker present), to avoid racing with the timer.

set -e

HOSTS="s01 c01 c02 c03"
SERVER="s01"

for host in $HOSTS; do
    if ssh "$host" "systemctl is-active --quiet nixos-upgrade.timer" </dev/null; then
        echo "error: $host is not in dev mode (nixos-upgrade.timer is still active)"
        echo "run ./dev-mode-on.sh first"
        exit 1
    fi
done

# Silence the shellInit banners on each host so scp's remote shell doesn't
# corrupt the SCP protocol with chatter. Removes both the dev-mode marker
# and any stale last-upgrade-failed marker. Safe: the timer is already
# stopped, which is the actual race protection. dev-mode-on.sh will recreate
# the dev-mode marker next time if needed.
for host in $HOSTS; do
    ssh "$host" "sudo rm -f /var/lib/nixos-nomad/dev-mode /var/lib/nixos-nomad/last-upgrade-failed" </dev/null
done

for host in $HOSTS; do
    ssh "$host" "sudo rm -rf nixos-config && mkdir nixos-config" </dev/null
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
