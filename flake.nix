{
  description = "Nuenv: a Nushell environment for Nix";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2305.*.tar.gz"; # Provides Nushell v0.81.0
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      supportedSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            self.overlays.nuenv # Supply nixpkgs.nuenv.mkDerivation
            rust-overlay.overlays.default
            (final: prev: {
              rustToolchain = prev.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
            })
          ];
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

            writeScriptBin = self.lib.mkNushellScript
              # Provide Nushell package
              prev.nushell
              # Provide helper function
              prev.writeTextFile;

            # TODO: mkShell
          };
        };
      };

      lib = {
        inherit (import ./lib/nuenv.nix)
          mkNushellDerivation
          mkNushellScript;
      };

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
            nu --config ${./nuenv/user-env.nu}
          '';
        };
      });

      packages = forAllSystems ({ pkgs, system }: rec {
        default = hello;

        run-me = pkgs.nuenv.writeScriptBin {
          name = "run-me";
          script = ''
            def color [color: string, msg: string] { $"(ansi $color)($msg)(ansi reset)" }
            def info [msg: string] { print $"(color "blue" "INFO"): ($msg)" }
            def success [msg: string] { print $"(color "green" $msg)" }

            info $"Hello, NixCon (date now | date format "%Y")!"
            info "So lovely to see everyone today"
            info "Conference status:"
            success "SUCCESS"
            info "Nearing completion..."
            info "Script status:"
            success "DONE"
          '';
        };

        nuenv-commands = pkgs.writeScriptBin "nuenv-commands" ''
          ${pkgs.nushell}/bin/nu --env-config ${./nuenv/user-env.nu} --commands "nuenvCommands"
        '';

        # For NixCon
        hello = pkgs.nuenv.mkDerivation {
          name = "hello-nix-nushell";
          packages = [ pkgs.hello ];
          src = ./.;
          build = builtins.readFile ./example/hello.nu;
          MESSAGE = "Hello from Nix + Bash";
        };

        # An example Nushell-based derivation
        nixcon = pkgs.nuenv.mkDerivation {
          name = "hello-nixcon";
          packages = [ pkgs.hello ];
          src = ./.;
          build = builtins.readFile ./example/hello.nu;
          MESSAGE = "NixCon ❄️! Servus, grüezi, hallo, und hallöchen 😄";
        };

        # The Nushell-based derivation above but with debug mode disabled
        helloNoDebug = pkgs.nuenv.mkDerivation {
          name = "hello-nix-nushell";
          packages = [ pkgs.hello ];
          src = ./.;
          build = builtins.readFile ./example/hello.nu;
          debug = false;
          MESSAGE = "Hello from Nix + Bash, but no debugging this time";
        };

        # A non-overlay version
        direct = self.lib.mkNushellDerivation pkgs.nushell system {
          name = "no-overlay";
          src = ./.;
          build = ''
            let share = $"($env.out)/share"
            (version).version | save nushell-version.txt
            mkdir $share
            cp nushell-version.txt $share
          '';
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
          buildInputs = [ pkgs.hello ];
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
            ls ${self.packages.${system}.hello}

            mkdir -p $out/share

            cp ${self.packages.${system}.hello}/share/hello.txt $out/share/copied.txt
          '';
        };

        # An Nushell-based derivation that errors
        error = pkgs.nuenv.mkDerivation {
          name = "throws-nushell-error";
          src = ./.;
          build = builtins.readFile ./example/error.nu;
        };
      });
    };
}
