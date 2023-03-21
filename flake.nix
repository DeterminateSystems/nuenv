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
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.nuenv ];
        };
        inherit system;
      });
    in
    {
      overlays = rec {
        default = nuenv;

        nuenv = final: prev: {
          nuenv = {
            mkDerivation = self.lib.mkNushellDerivation
              # Provide Nushell package
              prev.nushell
              # Provide default system
              prev.system;
          };
        };
      };

      lib = {
        # A derivation wrapper that calls a Nushell builder rather than the standard environment's
        # Bash builder.
        mkNushellDerivation =
          # nixpkgs.nushell (from overlay)
          nushell:

          # nixpkgs.system (from overlay)
          sys:

          { name                # The name of the derivation
          , src                 # The derivation's sources
          , packages ? [ ]      # Packages provided to the realisation process
          , system ? sys        # The build system
          , build ? ""          # The build phase
          , debug ? true        # Run in debug mode
          , outputs ? [ "out" ] # Outputs to provide
          , ...                 # Catch user-supplied env vars
          }@attrs:

          let
            # Gather arbitrary user-supplied env vars
            reservedAttrs = [
              "build"
              "debug"
              "name"
              "outputs"
              "packages"
              "src"
              "system"
              "__nu_debug"
              "__nu_extra_attrs"
              "__nu_packages"
              "__nu_user_env_file"
            ];

            extraAttrs = removeAttrs attrs reservedAttrs;
          in
          derivation {
            # Derivation
            inherit name outputs src system;

            # Phases
            inherit build;

            # Build logic
            builder = "${nushell}/bin/nu";
            args = [ ./nushell/builder.nu ];

            # When this is set, Nix writes the environment to a JSON file at
            # $NIX_BUILD_TOP/.attrs.json. Because Nushell can handle JSON natively, this approach
            # is generally cleaner than parsing environment variables as strings.
            __structuredAttrs = true;

            # Attributes passed to the environment (prefaced with __nu_ to avoid naming collisions)
            __nu_debug = debug;
            __nu_extra_attrs = extraAttrs;
            __nu_packages = packages;
            __nu_user_env_file = ./nushell/user-env.nu;
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
          default = hello;

          # An example Nushell-based derivation
          hello = pkgs.nuenv.mkDerivation {
            name = "hello-nix-nushell";
            packages = [ pkgs.hello ];
            src = ./.;
            build = builtins.readFile ./example/hello.nu;
            MESSAGE = "Hello from Nix + Bash";
          };

          # A non-overlay version
          direct = self.lib.mkNushellDerivation pkgs.nushell system {
            name = "no-overlay";
            src = ./.;
            build = ''
              (version).version | save nushell-version.txt
              cp nushell-version.txt $env.out
            '';
          };

          # The Nushell-based derivation above but with debug mode disabled
          helloNoDebug = pkgs.nuenv.mkDerivation {
            name = "hello-nix-nushell";
            packages = with pkgs; [ hello ];
            src = ./.;
            build = builtins.readFile ./example/hello.nu;
            debug = false;
            MESSAGE = "Hello from Nix + Bash";
          };

          # Show that Nuenv works when drawing sources from GitHub
          githubSrc = pkgs.nuenv.mkDerivation {
            name = "advanced-nix-nushell";
            src = pkgs.fetchFromGitHub {
              owner = "DeterminateSystems";
              repo = "nuenv";
              rev = "c8adf22d9cdc61d4777ad4b9d193e9b22547419e";
              sha256 = "sha256-fu4WTFHlceasWpi6zF0nlent4KSmPAdsiKTrGixDEiI=";
            };
            build = ''
              let share = $"($env.out)/share"
              mkdir $share
              cp README.md $share
            '';
          };

          # The same derivation above but using the stdenv
          stdenv = pkgs.stdenv.mkDerivation {
            name = "just-experimenting";
            buildInputs = with pkgs; [ hello ];
            src = ./.;
            buildPhase = ''
              hello --greeting "''${MESSAGE}" > hello.txt
              substituteInPlace hello.txt --replace "Bash" "Nushell"
            '';
            installPhase = ''
              mkdir -p $out/share
              cp hello.txt $out/share
            '';
            MESSAGE = "Hello from Nix + Bash";
          };

          # Simple that relies on the Nushell derivation
          other = pkgs.stdenv.mkDerivation {
            name = "other";
            src = ./.;
            installPhase = ''
              mkdir -p $out/share

              cp ${self.packages.${system}.default}/share/hello.txt $out/share/copied.txt
            '';
          };
        });
    };
}
