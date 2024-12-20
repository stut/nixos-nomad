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
		};
	};

	virtualisation = {
		docker = {
			enable = true;
		};
	};

	networking.firewall.allowedTCPPorts = [ 4646 4647 4648 9998 ];
	networking.firewall.allowedUDPPorts = [ 4648 ];
	
	systemd.services.nomad = {
		after = [ "network.target" ];
		serviceConfig = {
			Restart = lib.mkForce "always";
		};
	};
}

