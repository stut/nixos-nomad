{
  description = "Consul / Nomad cluster, Home Lab Edition";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.05";
  };

  outputs = { self, nixpkgs, ... } @ inputs:
    let
      # Configure your cluster here
      clusterConfig = {
        datacenterName = "home";
        serverIp = "192.168.192.10";
        sshPort = 64242;
        sshPublicKeys = [
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCQ3SV7ef3vQs2C6O3S/Yj88teBWmbGXYNoDmU7+tpyK32Phi4OZjceIZXXoA3+3jhksQCycKLOJtmuLCUw8Q0E="
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
    in
    {
      inherit lib;
      nixosConfigurations = {
        hybrid = lib.nixosSystem {
          modules = [ ./node-types/server ./node-types/client ];
          specialArgs = { inherit inputs outputs clusterConfig; };
        };
        server = lib.nixosSystem {
          modules = [ ./node-types/server ];
          specialArgs = { inherit inputs outputs clusterConfig; };
        };
        client = lib.nixosSystem {
          modules = [ ./node-types/client ];
          specialArgs = { inherit inputs outputs clusterConfig; };
        };
      };
    };
}
