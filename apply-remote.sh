#!/bin/sh
set -e

for host in s01 c01 c02 c03; do scp -r * ${host}:nixos-config/; done

echo
echo "--------------------------------"
echo
echo s01
ssh s01 "cd nixos-config && ./switch.sh server"

for host in c01 c02 c03; do
	echo
	echo "--------------------------------"
	echo
	echo $host
	ssh $host "cd nixos-config && ./switch.sh client"
done

