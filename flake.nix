{
  description = "nuenv: a Nushell environment for Nix";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable"; # Provides Nushell v0.76.0
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.nuenv ]; };
        inherit system;
      });
    in
    {
      overlays = rec {
        default = nuenv;

        nuenv = final: prev: {
          nuenv.mkDerivation = self.lib.mkNushellDerivation final;
        };
      };

      lib = {
        # A derivation wrapper that calls a Nushell builder rather than the standard environment's
        # Bash builder.
        mkNushellDerivation = pkgs:
          { name                # The name of the derivation
          , src                 # The derivation's sources
          , system              # The build system
          , packages ? [ ]      # Packages provided to the realisation process
          , build ? ""          # The build phase
          , debug ? true        # Run in debug mode
          , outputs ? [ "out" ] # Outputs to provide
          }:

          derivation {
            # Derivation
            inherit name outputs src system;

            # Phases
            inherit build;

            # Build logic
            builder = "${pkgs.nushell}/bin/nu";
            args = [ ./nushell/builder.nu ];

            # When this is set, Nix writes the environment to a JSON file at
            # $NIX_BUILD_TOP/.attrs.json. Because Nushell can handle JSON natively, this approach
            # is generally cleaner than parsing environment variables as strings.
            __structuredAttrs = true;

            # Attributes passed to the environment (prefaced with __nu_ to avoid naming collisions)
            __nu_user_env_file = ./nushell/user-env.nu;
            __nu_packages = packages;
            __nu_debug = debug;
          };
      };

      apps = forAllSystems ({ pkgs, system }: {
        default = {
          type = "app";
          program = "${pkgs.nushell}/bin/nu";
        };
      });

      devShells = forAllSystems ({ pkgs, system }: {
        default = pkgs.mkShell {
          packages = with pkgs; [ nushell ];
        };

        ci = pkgs.mkShell {
          packages = with pkgs; [ cachix direnv nushell ];
        };

        # A dev environment with Nuenv's helper functions available
        nuenv = pkgs.mkShell {
          packages = with pkgs; [ nushell ];
          shellHook = ''
            nu --config ./nushell/user-env.nu
          '';
        };
      });

      packages = forAllSystems
        ({ pkgs, system }: rec {
          default = nushell;

          # An example Nushell-based derivation
          nushell = pkgs.nuenv.mkDerivation {
            name = "cow-says-hello";
            inherit system;
            packages = with pkgs; [ coreutils ponysay ];
            outputs = [ "out" "doc" ];
            src = ./.;
            build = builtins.readFile ./example/build.nu;
            __nu_debug = false;
          };

          # The Nushell-based derivation above but with debug mode disabled
          nushellNoDebug = pkgs.nuenv.mkDerivation {
            name = "just-experimenting";
            inherit system;
            packages = with pkgs; [ coreutils ponysay ];
            src = ./.;
            build = builtins.readFile ./example/build.nu;
            debug = false;
          };

          test = pkgs.nuenv.mkDerivation {
            name = "test-nushell-logic";
            inherit system;
            packages = [ ];
            src = ./.;
            build = "";
            debug = true;
            test = true;
          };

          # The same derivation above but using the stdenv
          std = pkgs.stdenv.mkDerivation {
            name = "just-experimenting";
            inherit system;
            buildInputs = with pkgs; [ go ];
            src = ./.;
            outputs = [ "out" "doc" ];
            buildPhase = ''
              versionFile="go-version.txt"
              echo "Writing version info to ''${versionFile}"
              go version > $versionFile
              substituteInPlace $versionFile --replace "go" "golang"

              helpFile="go-help.txt"
              echo "Writing help info to ''${helpFile}"
              go help > $helpFile
              substituteInPlace $helpFile --replace "go" "golang"

              echo "Docs!" > docs.txt
            '';
            installPhase = ''
              mkdir -p $out/share
              cp go-*.txt $out/share

              mkdir -p $doc/share
              cp docs.txt $doc/share
            '';
          };

          # Derivation that relies on the Nushell derivation
          other = pkgs.stdenv.mkDerivation {
            name = "other";
            src = ./.;
            installPhase = ''
              mkdir -p $out/share

              cp ${self.packages.${system}.default}/share/happy-thought.txt $out/share/happy-though-about-nushell.txt
            '';
          };
        });
    };
}
