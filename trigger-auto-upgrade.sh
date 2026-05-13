#!/bin/sh
# Manually fire the auto-upgrade service on one or more nodes. Equivalent
# to waiting for the timer; pulls origin/main and rebuilds.
#
# Usage:
#   ./trigger-auto-upgrade.sh              # all hosts in order
#   ./trigger-auto-upgrade.sh c02 c03      # named hosts

set -e

ALL_HOSTS="s01 c01 c02 c03"
HOSTS=${*:-$ALL_HOSTS}

for host in $HOSTS; do
    echo
    echo "--------------------------------"
    echo "$host"
    echo "--------------------------------"
    ssh "$host" "sudo systemctl start nixos-upgrade.service"
done
