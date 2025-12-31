{
  description = "Consul / Nomad cluster, Home Lab Edition";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";
		consul-cni-flake.url = "github:stut/consul-cni.nix";
  };

  outputs = { self, nixpkgs, consul-cni-flake, ... } @ inputs:
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
    in
    {
      inherit lib;
      nixosConfigurations = {
        hybrid = lib.nixosSystem {
          modules = [ ./node-types/server ./node-types/client ];
          specialArgs = { inherit inputs outputs clusterConfig consul-cni; };
        };
        server = lib.nixosSystem {
          modules = [ ./node-types/server ];
          specialArgs = { inherit inputs outputs clusterConfig consul-cni; };
        };
        client = lib.nixosSystem {
          modules = [ ./node-types/client ];
          specialArgs = { inherit inputs outputs clusterConfig consul-cni; };
        };
      };
    };
}
