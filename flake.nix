{
  description = "Chip8 Emulator";

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
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig
            zls

            wayland
            libxkbcommon
            libGL

            alsa-lib
            libpulseaudio

            libX11
            libXcursor
            libXi
            libXrandr
          ];

          shellHook = ''
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath (with pkgs; [
            wayland
            libxkbcommon
            libGL
            alsa-lib
            libpulseaudio
            libX11
            libXcursor
            libXi
            libXrandr
          ])}:$LD_LIBRARY_PATH"
        '';
        };
      }
    );
}
