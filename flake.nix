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
        # A derivation wrapper that calls a Nushell builder rather than the standard environment's
        # Bash builder.
        mkNushellDerivation =
          { pkgs              # Pinned Nixpkgs
          , name              # The name of the derivation
          , system            # The build system
          , src               # The derivation's sources
          , buildPhase ? ""   # Same as buildPhase in stdenv
          , installPhase ? "" # Same as installPhase in stdenv
          , buildInputs ? [ ] # Same as buildInputs in stdenv
          }:

          let
            baseInputs = (with pkgs; [ nushell coreutils ]);
          in
          derivation {
            inherit name system src buildPhase installPhase;
            builder = "${pkgs.nushell}/bin/nu";
            args = [ ./builder.nu ];

            # Attributes passed to the environment (prefaced with __ to avoid naming collisions)
            __nushell_version = pkgs.nushell.version;
            __envFile = ./env.nu;
            __buildInputs = buildInputs ++ baseInputs;
          };
      };

      devShells = forAllSystems ({ pkgs, ... }: {
        default = pkgs.mkShell {
          packages = with pkgs; [ go nushell ];
        };
      });

      packages = forAllSystems ({ pkgs, system }: {
        default =
          let
            inText = "go";
            outText = "golang";
          in
          self.lib.mkNushellDerivation {
            name = "write-go-version";
            inherit pkgs system;
            src = ./.;
            buildInputs = with pkgs; [ go_1_18 ];
            buildPhase = ''
              go version | save go-version.txt
              go help | save help.txt
              substitute help.txt go-help.txt --replace ${inText} --with ${outText}
              substituteInPlace go-version.txt --replace ${inText} --with ${outText}
            '';
            installPhase = ''
              let share = $"($env.out)/share"
              mkdir $share
              [go-help.txt go-version.txt] | each {|f| mv $f $share}
            '';
          };
      });
    };
}
