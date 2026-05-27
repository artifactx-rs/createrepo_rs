{
  description = "Pure Rust RPM repository metadata generator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          default = pkgs.callPackage ./default.nix { };
          createrepo-rs = pkgs.callPackage ./default.nix { };
        };

        apps = {
          default = flake-utils.lib.mkApp {
            drv = self.packages.${system}.createrepo-rs;
          };
        };
      }
    ) // {
      overlays.default = final: prev: {
        createrepo-rs = final.callPackage ./default.nix { };
      };
    };
}
