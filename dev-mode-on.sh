#!/bin/sh
# Disable cluster-wide auto-upgrade so apply-remote.sh can push a working
# tree without the timer racing it.

set -e

HOSTS="s01 c01 c02 c03"

for host in $HOSTS; do
    echo "$host: enabling dev mode"
    ssh "$host" "sudo systemctl stop nixos-upgrade.timer; \
                 sudo mkdir -p /var/lib/nixos-nomad; \
                 sudo touch /var/lib/nixos-nomad/dev-mode"
done

echo
echo "dev mode is ON across the cluster. run ./dev-mode-off.sh when done."
