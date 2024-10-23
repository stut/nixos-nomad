#!/bin/sh
if [ -z "$1" ]; then
    echo "Usage: $0 server|client|hybrid"
    exit 1
fi

# Use the hardware configuration created by the installer
cp -f /etc/nixos/hardware-configuration.nix ./hardware-configuration.nix

# Switch to the configuration specified by the argument
sudo nixos-rebuild switch --show-trace --flake .#$1
