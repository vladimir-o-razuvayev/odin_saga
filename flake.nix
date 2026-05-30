{
  description = "Interactive fiction/story-game compiler";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem = {pkgs, ...}: let
        odin = pkgs.callPackage ./nix/odin.nix {};
        saga = pkgs.callPackage ./nix {inherit odin;};
      in {
        packages.default = saga;
        devShells.default = pkgs.callPackage ./nix/shell.nix {inherit odin;};
        checks.default = saga;
      };
    };
}
