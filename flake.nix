{
  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs flake-utils.lib.defaultSystems (system: f {
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
          { pkgs              # Pinned Nixpkgs
          , name              # The name of the derivation
          , src ? ./.         # The derivation's sources
          , system            # The build system
          , buildInputs ? [ ] # Same as buildInputs in stdenv
          , buildPhase ? ""   # Same as buildPhase in stdenv
          , installPhase ? "" # Same as installPhase in stdenv
          }:

          let
            baseInputs = (with pkgs; [ nushell ]);
          in
          derivation {
            inherit name src system buildPhase installPhase;
            builder = "${pkgs.nushell}/bin/nu";
            args = [ ./builder.nu ];

            # Attributes passed to the environment (prefaced with __ to avoid naming collisions)
            __nu_nushell_version = pkgs.nushell.version;
            __nu_envFile = ./env.nu;
            __nu_buildInputs = buildInputs ++ baseInputs;
          };
      };

      devShells = forAllSystems ({ pkgs, system }: {
        default = pkgs.mkShell {
          packages = with pkgs; [ go nushell ];
        };
      });

      packages = forAllSystems ({ pkgs, system }: {
        default =
          pkgs.nuenv.mkDerivation {
            name = "write-go-version";
            inherit pkgs system;
            buildInputs = with pkgs; [ go ];
            buildPhase = ''
              let versionFile = "go-version.txt"
              echo $"Writing version info to ($versionFile)"
              go version | save $versionFile

              let helpFile = "go-help.txt"
              echo $"Writing help info to ($helpFile)"
              go help | save $helpFile

              [$versionFile $helpFile] | each {|f|
                substituteInPlace $f --replace go --with golang
                substituteInPlace $f --replace Go --with GOLANG
              }

              substituteInPlace non-existent.txt --replace goo --with bar
            '';
            installPhase = ''
              let share = $"($env.out)/share"
              mkdir $share
              [go-help.txt go-version.txt] | each { |file| mv $file $share }
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
