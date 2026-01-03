{ lib, pkgs, clusterConfig, consul-cni, ... }:
{
	nixpkgs.config.allowUnfree = true;

	services.nomad = {
		enable = true;
		package = pkgs.nomad;

		extraPackages = with pkgs; [
			cni-plugins
			consul-cni
		];

		# Add Docker driver.
		enableDocker = true;
		# Add extra plugins to Nomads plugin directory.
		extraSettingsPlugins = [ ];

		# Nomad as Root to access Docker sockets.
		dropPrivileges = false;

		# Nomad configuration, as Nix attribute set.
		settings = {
			bind_addr = "0.0.0.0";
			advertise = {
				http = "{{ GetPrivateInterfaces | include \"network\" \"192.168.192.0/24\" | attr \"address\" }}";
				rpc = "{{ GetPrivateInterfaces | include \"network\" \"192.168.192.0/24\" | attr \"address\" }}";
				serf = "{{ GetPrivateInterfaces | include \"network\" \"192.168.192.0/24\" | attr \"address\" }}";
			};
			datacenter = clusterConfig.datacenterName;
			leave_on_interrupt = true;
			leave_on_terminate = true;
			
			server = {
				enabled = false;
			};
			
			client = {
				enabled = true;
				servers = [clusterConfig.serverIp];
				drain_on_shutdown = {
					deadline           = "5m";
					force              = false;
					ignore_system_jobs = false;
				};
				cni_path = "${pkgs.cni-plugins}/bin:${consul-cni}/bin";
				artifact = {
					disable_filesystem_isolation = true;
				};
			};
			
			plugin = {
				raw_exec = {
					config = {
					  enabled = true;
					};
				};

				docker = {
					config = {
						allow_privileged = true;
					};
				};
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

	virtualisation = {
		docker = {
			enable = true;
		};
	};

	networking.firewall.allowedTCPPorts = [ 4646 4647 4648 9998 ];
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
		after = [ "network.target" "generate-node-name.service" "systemd-tmpfiles-setup.service" "consul.service" ];
		wants = [ "consul.service" ];
		requires = [ "generate-node-name.service" ];
		serviceConfig = {
			Restart = lib.mkForce "always";
			# Allow writing to /var/lib/nomad for config files
			ReadWritePaths = [ "/var/lib/nomad" ];
		};
		preStart = ''
			# Ensure node name file exists (should be created by generate-node-name.service)
			if [ ! -f /var/lib/nomad-consul-node-name ]; then
				echo "Error: Node name file not found. generate-node-name.service may have failed." >&2
				exit 1
			fi
			# Read node name and create Nomad config file with node name
			NODE_NAME=$(cat /var/lib/nomad-consul-node-name)
			if [ -z "$NODE_NAME" ]; then
				echo "Error: Node name file is empty" >&2
				exit 1
			fi
			# Create Nomad config snippet with node name
			# Use /var/lib/nomad/config.d which is writable and where Nomad can read config files
			# Directory should already exist from systemd-tmpfiles, but ensure it's there
			# Since dropPrivileges = false, we run as root, so we can write here
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
			
			# Get the node's IP address from the private network interface
			# This matches the network used by Nomad (192.168.192.0/24)
			NODE_IP=$(ip -4 addr show | grep -oP 'inet \K192\.168\.192\.\d+' | head -n1)
			if [ -z "$NODE_IP" ]; then
				echo "Warning: Could not determine node IP address, service may not be discoverable" >&2
				NODE_IP=""
			fi
			
			# Register Nomad metrics service in Consul
			# Use explicit IP address so Prometheus can scrape without DNS resolution
			cat > /etc/consul.d/nomad-metrics.json <<EOFCONSUL
{
  "service": {
    "name": "nomad-metrics",
    "tags": ["prometheus", "metrics", "nomad-client"],
    "address": "$NODE_IP",
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

