#!/bin/sh
usage() {
    echo "Usage: $0 switch|boot server|client|hybrid"
    exit 1
}

OP=$1
TYPE=$2

case $OP in
    switch|boot)
        ;;
    *)
        usage
esac

case $TYPE in
    server|client|hybrid)
        ;;
    *)
        usage
esac

# Use the hardware configuration created by the installer
cp -f /etc/nixos/hardware-configuration.nix ./hardware-configuration.nix
sudo nixos-rebuild $OP --flake .#$TYPE
