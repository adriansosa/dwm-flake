{
  description = "DWM flake by adriansosa";

  # Nixpkgs / NixOS version to use.
  inputs = {
    nixpkgs = {
      url = "nixpkgs/nixos-21.11";
    };
    nixpkgs-unstable = {
      url = "nixpkgs/nixos-unstable";
    };

    flake-utils.url = "github:numtide/flake-utils";

    # dwm
    dwm = {
      url = "git+https://git.suckless.org/dwm";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }:
  let

    # Generate a user-friendly version number.
    version = "6.3";

    # System types to support.
    supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

    # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Nixpkgs instantiated for supported system types.
    nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

  in

  {

    # A Nixpkgs overlay.
    overlay = final: prev: {

      dwm = with final; stdenv.mkDerivation rec {
        name = "dwm-${version}";

        src = fetchgit {
          url = "git://git.suckless.org/dwm";
          rev = "refs/tags/6.3";
          sha256 = "pd1yi+DQ7xEV0iDyX+jC4KtcsfnqTH5ZOmPw++gSt8E=";
        };

        configFile = writeText "config.h" (builtins.readFile ./dwm-config.h);

        buildInputs = [ pkg-config xorg.libX11 xorg.libXinerama xorg.libXft ];

        buildPhase = ''
        cp ${configFile} config.h
        make dwm
        '';

        installPhase = ''
        mkdir -p $out/bin
        cp dwm $out/bin
        '';
      };

    };

    # Provide some binary packages for selected system types.
    packages = forAllSystems (system:
    {
      inherit (nixpkgsFor.${system}) dwm;
    });

    # The default package for 'nix build'. This makes sense if the
    # flake provides only one package or there is a clear "main"
    # package.
    defaultPackage = forAllSystems (system: self.packages.${system}.dwm);

    # A NixOS module, if applicable (e.g. if the package provides a system service).
    nixosModules.dwm =
      { pkgs, ... }:
      {
        nixpkgs.overlays = [ self.overlay ];

        environment.systemPackages = [ pkgs.dwm ];

        #systemd.services = { ... };
      };

    # Tests run by 'nix flake check' and by Hydra.
    checks = forAllSystems
    (system:
    with nixpkgsFor.${system};

    {
      inherit (self.packages.${system}) dwm;

      # Additional tests, if applicable.
      test = stdenv.mkDerivation {
        name = "dwm-test-${version}";
        configFile = super.writeText "config.h" (builtins.readFile ./dwm-config.h);

        buildInputs = [ ];

        #unpackPhase = "true";

        buildPhase = ''
        make
        echo 'running some integration tests'
        echo 'Done!'
        '';

        installPhase = ''
        mkdir -p $out
        cp dwm $out/bin
        '';
      };
    }

    // lib.optionalAttrs stdenv.isLinux {
      # A VM test of the NixOS module.
      vmTest =
        with import (nixpkgs + "/nixos/lib/testing-python.nix") {
          inherit system;
        };

        makeTest {
          nodes = {
            client = { ... }: {
              imports = [ self.nixosModules.dwm];
            };
          };

          testScript =
            ''
            '';
          };
        }
    );

  };
}
