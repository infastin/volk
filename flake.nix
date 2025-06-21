{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          system = system;
        };
      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            vala
            vala-language-server
            gcc
            meson
            pkg-config
            ninja
            wrapGAppsHook3
          ];
          buildInputs = with pkgs; [
            glib
            gtk3
            libnotify
            wireplumber
          ];
        };
      });
}
