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
				encrypt = "Q8kjhnRbGlCYhKJQcAbJwLBcfESabQ6zs+qUjqpUUy4=";
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

	systemd.services.nomad = {
		after = [ "network.target" "generate-server-node-name.service" ];
		requires = [ "generate-server-node-name.service" ];
		serviceConfig = {
			Restart = lib.mkForce "always";
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
			# Nomad reads all .hcl files in the config directory
			mkdir -p /etc/nomad.d
			cat > /etc/nomad.d/node-name.hcl <<EOF
name = "$NODE_NAME"
EOF
		'';
	};
}

