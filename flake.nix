{
  description = "Satifile nixos config";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11"; };

  outputs = { self, ... }@inputs:
    with inputs; {
      nixosConfigurations = {

        satifile = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./configuration.nix ];
        };

      };

    };
}
