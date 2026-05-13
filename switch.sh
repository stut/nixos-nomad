#!/bin/sh
# Apply the configuration from the current working directory.
#
# Intended for dev-mode use: the workstation `apply-remote.sh` script scps
# this directory to ~admin/nixos-config/ on each node and runs us. In
# production, the auto-upgrade timer applies from /etc/nixos directly.
#
# Copies per-host files (hardware-configuration.nix, node.json) from
# /etc/nixos so this dev tree matches the real node identity.

set -e

if [ ! -f /etc/nixos/node.json ]; then
    echo "error: /etc/nixos/node.json missing — node not bootstrapped"
    exit 1
fi

cp -f /etc/nixos/hardware-configuration.nix ./hardware-configuration.nix
cp -f /etc/nixos/node.json ./node.json

sudo nixos-rebuild switch --show-trace --flake "path:$(pwd)#auto"
