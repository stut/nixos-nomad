{ lib, pkgs, clusterConfig, consul-cni, ... }:
{
	nixpkgs.config.allowUnfree = true;

	services.nomad = {
		enable = true;
		package = pkgs.nomad;

		extraPackages = [
			pkgs.cni-plugins
			consul-cni
		];

		settings = {
			bind_addr = "0.0.0.0";
			datacenter = clusterConfig.datacenterName;
			
			server = {
				enabled = true;
				bootstrap_expect = 1;
			};

			client = {
				enabled = false;
				cni_path = "${pkgs.cni-plugins}/bin:${consul-cni}/bin";
			};
			
			consul = {
				address = "127.0.0.1:8500";
				grpc_address = "127.0.0.1:8502";

				server_service_name = "nomad-server";
				client_service_name = "nomad-client";

				auto_advertise = true;

				server_auto_join = true;
				client_auto_join = true;
			};

			acl = {
				enabled = false;
			};

			telemetry = {
				collection_interval = "1s";
				disable_hostname = true;
				prometheus_metrics = true;
				publish_allocation_metrics = true;
				publish_node_metrics = true;
			};
		};
	};

	networking.firewall.allowedTCPPorts = [ 4646 4647 4648  ];
	networking.firewall.allowedUDPPorts = [ 4648 ];

	# Ensure /var/lib/nomad/config.d exists and is writable
	# Create it with 1777 permissions (sticky bit + world writable) so any user can write
	# Also ensure /etc/consul.d exists for service registration
	systemd.tmpfiles.rules = [
		"d /var/lib/nomad 0755 root root -"
		"d /var/lib/nomad/config.d 1777 root root -"
		"d /etc/consul.d 0755 root root -"
	];

	systemd.services.nomad = {
		after = [ "network.target" "generate-server-node-name.service" "systemd-tmpfiles-setup.service" "consul.service" ];
		wants = [ "consul.service" ];
		requires = [ "generate-server-node-name.service" ];
		serviceConfig = {
			Restart = lib.mkForce "always";
			# Allow writing to /var/lib/nomad for config files
			ReadWritePaths = [ "/var/lib/nomad" ];
		};
		preStart = ''
			# Ensure node name file exists (should be created by generate-server-node-name.service)
			if [ ! -f /var/lib/nomad-consul-server-node-name ]; then
				echo "Error: Node name file not found. generate-server-node-name.service may have failed." >&2
				exit 1
			fi
			# Read node name and create Nomad config file with node name
			NODE_NAME=$(cat /var/lib/nomad-consul-server-node-name)
			if [ -z "$NODE_NAME" ]; then
				echo "Error: Node name file is empty" >&2
				exit 1
			fi
			# Create Nomad config snippet with node name
			# Directory is created with 1777 permissions so any user can write
			mkdir -p /var/lib/nomad/config.d
			cat > /var/lib/nomad/config.d/node-name.hcl <<EOF
name = "$NODE_NAME"
EOF
		'';
	};

	# Separate service to register Nomad metrics in Consul (runs as root)
	systemd.services.register-nomad-metrics = {
		description = "Register Nomad metrics service in Consul for Prometheus discovery";
		after = [ "network.target" "consul.service" "nomad.service" ];
		wants = [ "consul.service" "nomad.service" ];
		path = with pkgs; [ curl consul ];
		serviceConfig = {
			Type = "oneshot";
			RemainAfterExit = true;
		};
		script = ''
			# Wait for Nomad to be ready
			for i in {1..30}; do
				if curl -s -f http://127.0.0.1:4646/v1/metrics > /dev/null 2>&1; then
					break
				fi
				sleep 1
			done
			
			# Register Nomad metrics service in Consul
			# Use explicit IP address so Prometheus can scrape without DNS resolution
			cat > /etc/consul.d/nomad-metrics.json <<EOFCONSUL
{
  "service": {
    "name": "nomad-metrics",
    "tags": ["prometheus", "metrics", "nomad-server"],
    "address": "${clusterConfig.serverIp}",
    "port": 4646,
    "meta": {
      "prometheus_path": "/v1/metrics",
      "prometheus_scheme": "http"
    },
    "checks": [
      {
        "http": "http://127.0.0.1:4646/v1/metrics",
        "interval": "10s",
        "timeout": "3s"
      }
    ]
  }
}
EOFCONSUL
			
			# Reload Consul to pick up the new service definition
			# Use SIGHUP to reload, which is more reliable than 'consul reload'
			consul reload || pkill -HUP consul || true
		'';
	};
}

