{
  inputs = {
    nixpkgs.url = "nixpkgs/release-22.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs flake-utils.lib.defaultSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
        inherit system;
      });
    in
    {
      lib = {
        mkNushellDerivation =
          { pkgs
          , name
          , system
          , src
          , buildPhase ? ""
          , installPhase ? ""
          , preBuild ? ""
          , buildInputs ? [ ]
          }:

          let
            baseInputs = (with pkgs; [ nushell coreutils ]);
          in
          derivation {
            inherit name system src;
            builder = "${pkgs.nushell}/bin/nu";
            args = [ ./builder.nu ];
            NUSHELL_VERSION = pkgs.nushell.version;

            inherit buildPhase installPhase preBuild;

            buildInputs = buildInputs ++ baseInputs;
          };
      };

      devShells = forAllSystems ({ pkgs, ... }: {
        default = pkgs.mkShell {
          packages = with pkgs; [ go nushell ];
        };
      });

      packages = forAllSystems ({ pkgs, system }: {
        default = self.lib.mkNushellDerivation {
          name = "write-go-version";
          inherit pkgs system;
          src = ./.;
          buildInputs = with pkgs; [ go ];
          buildPhase = ''
            go version | save go-version.txt
          '';
          installPhase = ''
            let share = $"($env.out)/share"
            mkdir $share
            mv go-version.txt $share
          '';
        };
      });
    };
}
