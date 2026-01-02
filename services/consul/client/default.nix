{ lib, pkgs, clusterConfig, ... }:
let
  generateNodeName = pkgs.writeShellScript "generate-node-name" ''
    #!/usr/bin/env bash
    MACHINE_ID_FILE="/etc/machine-id"
    NODE_NAME_FILE="/var/lib/nomad-consul-node-name"
    
    if [ ! -f "$MACHINE_ID_FILE" ]; then
      echo "Error: $MACHINE_ID_FILE not found" >&2
      exit 1
    fi
    
    # Read machine-id and take first 8 characters
    MACHINE_ID=$(cat "$MACHINE_ID_FILE" | tr -d '\n' | head -c 8)
    NODE_NAME="client-''${MACHINE_ID}"
    HOSTNAME="''${NODE_NAME}.l51.net"
    
    # Write to file for other services to read
    mkdir -p "$(dirname "$NODE_NAME_FILE")"
    echo "$NODE_NAME" > "$NODE_NAME_FILE"
    
    # Set system hostname by writing to /etc/hostname (systemd will pick it up)
    echo "$HOSTNAME" > /etc/hostname
    # Also set it immediately using hostname command (doesn't require D-Bus)
    hostname "$HOSTNAME" 2>/dev/null || true
    
    echo "$NODE_NAME"
  '';
in
{
  services.consul = {
    enable = true;
    package = pkgs.consul;

    extraConfig = {
      datacenter = clusterConfig.datacenterName;
      log_level = "INFO";
      server = false;
      retry_join = [clusterConfig.serverIp];
      leave_on_terminate = true;
      bind_addr = "{{ GetPrivateInterfaces | include \"network\" \"192.168.192.0/24\" | attr \"address\" }}";
      ports = {
        grpc = 8502;
        dns = 8600;
      };
      recursors = [ "1.1.1.1" "1.0.0.1" ];
			encrypt = "CJ0ncDhP92euWlWX5EGv2KqBfSkQzEYjXCKTy+VWk3s=";
			#verify_incoming = true;
			#verify_outgoing = true;
			#verify_server_hostname = true;
			connect = {
				enabled = true;
			};
			ui = false;
    };
  };

  networking.firewall.allowedTCPPorts = [ 8500 8501 8502 8503 8600 8300 8301 8302 ];
  networking.firewall.allowedUDPPorts = [ 8600 8300 8301 8302 ];

  systemd.services.consul = {
    after = [ "network.target" "generate-node-name.service" ];
    requires = [ "generate-node-name.service" ];
    serviceConfig = {
      Restart = lib.mkForce "always";
    };
    preStart = ''
      # Ensure node name file exists
      if [ ! -f /var/lib/nomad-consul-node-name ]; then
        ${generateNodeName}
      fi
      # Create Consul config file with node_name
      NODE_NAME=$(cat /var/lib/nomad-consul-node-name)
      mkdir -p /etc/consul.d
      echo "{\"node_name\": \"$NODE_NAME\"}" > /etc/consul.d/node-name.json
    '';
  };

  # Service to generate node name from machine-id
  systemd.services.generate-node-name = {
    description = "Generate unique node name from machine-id";
    wantedBy = [ "multi-user.target" "consul.service" "nomad.service" ];
    before = [ "consul.service" "nomad.service" ];
    after = [ "systemd-hostnamed.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${generateNodeName}";
    };
  };
}
