{
  description = "nuenv: a Nushell environment for Nix";

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
      overlays = {
        nuenv = (final: prev: {
          nuenv.mkDerivation = self.lib.mkNushellDerivation;
        });
      };

      lib = {
        # A derivation wrapper that calls a Nushell builder rather than the standard environment's
        # Bash builder.
        mkNushellDerivation =
          { nushell        # Nushell package
          , name           # The name of the derivation
          , src            # The derivation's sources
          , system         # The build system
          , packages ? [ ] # Packages provided to the realisation process
          , build ? ""     # The Nushell script used for realisation
          }:

          derivation {
            inherit name src system;
            builder = "${nushell}/bin/nu";
            args = [ ./builder.nu ];

            # Attributes passed to the environment (prefaced with __nu_ to avoid naming collisions)
            __nu_nushell_version = nushell.version;
            __nu_envFile = ./env.nu;
            __nu_packages = packages ++ [ nushell ];

            build =
              if builtins.isString build then
                build
              else if builtins.isPath build then
                (builtins.readFile build)
              else throw "build attribute must be either a string or a path"
            ;
          };
      };

      devShells = forAllSystems ({ pkgs, system }: {
        default = pkgs.mkShell {
          packages = with pkgs; [ go nushell ];
        };

        nuenv = pkgs.mkShell {
          packages = with pkgs; [ nushell ];
          shellHook = ''
            nu --config ./env.nu
          '';
        };
      });

      packages = forAllSystems ({ pkgs, system }: {
        default =
          let
            curl = "${pkgs.curl}/bin/curl";
          in
          pkgs.nuenv.mkDerivation {
            name = "just-experimenting";
            inherit system;
            nushell = pkgs.nushell;
            packages = with pkgs; [ go ];
            src = ./.;
            build = ''
              let share = $"($env.out)/share"
              mkdir $share

              let versionFile = $"($share)/go-version.txt"
              echo $"Writing version info to ($versionFile)"
              go version | save $versionFile

              let helpFile = $"($share)/go-help.txt"
              echo $"Writing help info to ($helpFile)"
              go help | save $helpFile

              [$versionFile $helpFile] | each {|f|
                substituteInPlace $f --replace "go" --with "golang"
              }
            '';
          };

        # Derivation that relies on the Nushell derivation
        other = pkgs.stdenv.mkDerivation {
          name = "other";
          src = ./.;
          installPhase = ''
            mkdir -p $out/share

            cp ${self.packages.${system}.default}/share/go-version.txt $out/share/version.txt
          '';
        };
      });
    };
}
