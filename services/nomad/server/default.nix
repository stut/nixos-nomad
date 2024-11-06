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
		after = [ "network.target" ];
		serviceConfig = {
			Restart = lib.mkForce "always";
		};
	};
}

