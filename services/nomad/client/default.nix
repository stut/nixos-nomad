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
	
	# Ensure /var/lib/nomad/config.d exists and is writable
	# Create it with 1777 permissions (sticky bit + world writable) so any user can write
	systemd.tmpfiles.rules = [
		"d /var/lib/nomad 0755 root root -"
		"d /var/lib/nomad/config.d 1777 root root -"
	];

	systemd.services.nomad = {
		after = [ "network.target" "generate-node-name.service" "systemd-tmpfiles-setup.service" ];
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
}

