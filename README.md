# Nuenv: an experimental Nushell environment for Nix

[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/DeterminateSystems/nuenv/badge)](https://flakehub.com/flake/DeterminateSystems/nuenv)
![GitHub Actions status badge](https://github.com/DeterminateSystems/nuenv/actions/workflows/ci.yml/badge.svg?branch=main)

> [!INFO]
> Nuenv was a fun and instructive experiment but we don't plan to develop it further at this time, so we've opted to archive this repository.
> To read more about Nuenv, see the [Nuenv: an experimental Nushell environment for Nix][post] blog post on the [Determinate Systems blog][blog] and the [Nuenv: an experimental derivation builder for Nix][talk] talk at NixCon 2023.
> Going forward, you're free to use this project [as you see fit](./LICENSE)!

This repo houses an example project that uses [Nushell] as an alternative builder for [Nix] (whose standard environment uses [Bash]).
For more information, check out [Nuenv: an experimental Nushell environment for Nix][post] on the [Determinate Systems blog][blog].

## Running the scenario

First, make sure that you have [Nix] installed with [flakes enabled][flake].
We recommend using our [Determinate Nix Installer][dni]:

```shell
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install
```

With Nix installed, you can [realise] a Nix [derivation] that uses Nushell rather than Bash:

```shell
nix build --print-build-logs

# Or without cloning this repo
nix build --print-build-logs "https://flakehub.com/f/DeterminateSystems/nuenv/*.tar.gz"
```

You should see build output like this:

```shell
hello-nix-nushell> >>> INFO
hello-nix-nushell> > Realising the hello-nix-nushell derivation for aarch64-darwin
hello-nix-nushell> > Using Nushell 0.77.0
hello-nix-nushell> > Declared build outputs:
hello-nix-nushell> + out
hello-nix-nushell> >>> SETUP
hello-nix-nushell> > Adding 1 package to PATH:
hello-nix-nushell> + hello-2.12.1
hello-nix-nushell> > Setting PATH
hello-nix-nushell> > Setting 1 user-supplied environment variable:
hello-nix-nushell> + MESSAGE = "Hello from Nix + Bash"
hello-nix-nushell> > Copying sources
hello-nix-nushell> > Creating output directories
hello-nix-nushell> >>> REALISATION
hello-nix-nushell> > Running build phase
hello-nix-nushell> + Running hello version 2.12.1
hello-nix-nushell> + Creating output directory at /nix/store/n0dqy5gpshz21hp1qhgj6795nahqpdyc-hello-nix-nushell/share
hello-nix-nushell> + Writing hello message to /nix/store/n0dqy5gpshz21hp1qhgj6795nahqpdyc-hello-nix-nushell/share/hello.txt
hello-nix-nushell> + Substituting Bash for Nushell in /nix/store/n0dqy5gpshz21hp1qhgj6795nahqpdyc-hello-nix-nushell/share/hello.txt
hello-nix-nushell> >>> DONE!
hello-nix-nushell> > out output written to /nix/store/n0dqy5gpshz21hp1qhgj6795nahqpdyc-hello-nix-nushell
```

This derivation does something very straightforward: it provides a message to GNU's [hello] tool and saves the result in a text file called `hello.txt` under the `share` directory.

```shell
cat ./result/share/hello.txt
```

## How it works

The key differentiator from regular Nix here is that realisation happens in [Nushell] scripts rather than in [Bash].
The project's [flake] outputs a function called `mkNushellDerivation` that wraps Nix's built-in [`derivation`][derivation] function but, in contrast to [`stdenv.mkDerivation`][stdenv], uses Nushell as the `builder`, which in turn runs a [`builder.nu`](./nuenv/builder.nu) script that provides the Nix environment.
In addition to `builder.nu`, [`env.nu`](./nuenv/env.nu) provides helper functions to your realisation scripts.

## Try it out

You can use nuenv to realise your own derivations.
Here's a straightforward example:

```nix
{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2311.*.tar.gz";
    nuenv.url = "https://flakehub.com/f/DeterminateSystems/nuenv/*.tar.gz";
  };

  outputs = { self, nixpkgs, nuenv }: let
    overlays = [ nuenv.overlays.default ];
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
      inherit system;
      pkgs = import nixpkgs { inherit overlays system; };
    });
  in {
    packages = forAllSystems ({ pkgs, system }: {
      default = pkgs.nuenv.mkDerivation {
        name = "hello";
        src = ./.;
        inherit system;
        # This script is Nushell, not Bash
        packages = with pkgs; [ hello ];
        build = ''
          hello --greeting $"($env.MESSAGE)" | save hello.txt
          let out = $"($env.out)/share"
          mkdir $out
          cp hello.txt $out
        '';
        MESSAGE = "My custom Nuenv derivation!";
      };
    });
  };
}
```

To build and view the result of this derivation:

```shell
nix build
cat ./result/share/hello.txt
```

## Creating Nushell scripts

Nuenv has a `writeScriptBin` function that you can use to wrap [Nushell] scripts using Nix.
Here's an example:

```nix
# This example is only for x86_64-linux; adjust for your own platform
{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2311.*.tar.gz";
    nuenv.url = "https://flakehub.com/f/DeterminateSystems/nuenv/*.tar.gz";
  };

  outputs = { self, nixpkgs, nuenv }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ nuenv.overlays.nuenv ];
    };
  in {
    packages.x86_64-linux.run-me = pkgs.nuenv.writeScriptBin {
      name = "run-me";
      script = ''
        def blue [msg: string] { $"(ansi blue)($msg)(ansi reset)" }
        blue "Hello world"
      '';
    };
  };
}
```

`writeScriptBin` serves the same purpose as [`writeScriptBin`][writescriptbin] in the Nixpkgs standard environment but for Nushell instead of [Bash].

[bash]: https://gnu.org/software/bash
[blog]: https://determinate.systems/posts
[derivation]: https://zero-to-nix.com/concepts/derivations
[dni]: https://github.com/DeterminateSystems/nix-installer
[flake]: https://zero-to-nix.com/concepts/flakes
[hello]: https://gnu.org/software/hello
[nix]: https://nixos.org
[nushell]: https://nushell.sh
[post]: https://determinate.systems/posts/nuenv
[realise]: https://zero-to-nix.com/concepts/realisation
[stdenv]: https://ryantm.github.io/nixpkgs/stdenv/stdenv
[talk]: https://www.youtube.com/watch?v=QwElUltNsq0
[writescriptbin]: https://ryantm.github.io/nixpkgs/builders/trivial-builders/#trivial-builder-writeText
