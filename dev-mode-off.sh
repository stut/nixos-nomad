#!/bin/sh
# Re-enable cluster-wide auto-upgrade.

set -e

HOSTS="s01 c01 c02 c03"

for host in $HOSTS; do
    echo "$host: disabling dev mode"
    ssh "$host" "sudo systemctl unmask nixos-upgrade.service; \
                 sudo systemctl start nixos-upgrade.timer; \
                 sudo rm -f /var/lib/nixos-nomad/dev-mode"
done

echo
echo "dev mode is OFF. auto-upgrade timer is running."
