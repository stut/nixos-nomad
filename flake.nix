{
  description = "Consul / Nomad cluster, Home Lab Edition";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";
		consul-cni-flake.url = "github:stut/consul-cni.nix";
		sops-nix = {
			url = "github:Mic92/sops-nix";
			inputs.nixpkgs.follows = "nixpkgs";
		};
  };

  outputs = { self, nixpkgs, consul-cni-flake, sops-nix, ... } @ inputs:
    let
      # Configure your cluster here
      clusterConfig = {
        datacenterName = "home";
        serverIp = "192.168.192.10";
        sshPort = 64242;
        sshPublicKeys = [
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCQ3SV7ef3vQs2C6O3S/Yj88teBWmbGXYNoDmU7+tpyK32Phi4OZjceIZXXoA3+3jhksQCycKLOJtmuLCUw8Q0E="
					"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDCCHpc5UQlOrcYoqytTzKF4KXjtii322xUCetC/y/yte08P/qh7hMj/A6g/keXClSmYzo/LWEILDpu8F0QOmLC6GV07jre/ELEZSTakqHVrI9Uw2iyaz80z1yqljKZqD4hlGTL4lbmAkpZJCN7W9RSjedI084L7LOoIAoISr6SfOmkGr2dB3vaB2p3Krc/guEMogWYxfmbItMgyQpBaM/ubMPHBDA+RHqqXr3DK9YLq3JZtFN/5wjzokC2aC1mYaoRV35kkG1hFZoZk2PeJUGpXIJxfWheAuCOcM9bKlImJ8UGbn/6DXtpGDIpjuHh1cePhdsi5mnl8rKGbbC4B/Zf"
        ];
        # Persistent storage via an SMB share on a NAS. Set enable = false
        # to skip mounting any share — clients will not include cifs-utils
        # and no secrets will be required.
        nas = {
          enable = true;
          host = "192.168.192.234";
          share = "nomad-data";
          mountPoint = "/mnt/nas/vault";
        };
      };
      # End configuration

      inherit (self) outputs;
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
      ];
      forEachSystem = f: lib.genAttrs systems (system: f pkgsFor.${system});
      pkgsFor = lib.genAttrs systems (system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      });
			consul-cni = consul-cni-flake.packages.x86_64-linux.consul-cni;

      # Per-host configuration. node.json is gitignored and populated at
      # install time. Falls back to a hybrid/ordinal-0 default so a fresh
      # checkout still evaluates (e.g. for `nix flake check`).
      nodeConfig =
        if builtins.pathExists ./node.json
        then builtins.fromJSON (builtins.readFile ./node.json)
        else { role = "hybrid"; ordinal = 0; };

      roleModules = {
        server = [ ./node-types/server ];
        client = [ ./node-types/client ];
        hybrid = [ ./node-types/server ./node-types/client ];
      };

      modulesForRole = role:
        if roleModules ? ${role}
        then roleModules.${role}
        else throw "Invalid role in node.json: ${role} (expected server, client, or hybrid)";
    in
    {
      inherit lib;
      nixosConfigurations = {
        auto = lib.nixosSystem {
          modules = [ sops-nix.nixosModules.sops ] ++ (modulesForRole nodeConfig.role);
          specialArgs = { inherit inputs outputs clusterConfig consul-cni nodeConfig; };
        };
      };
    };
}
