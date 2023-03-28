# Nuenv: an experimental Nushell environment for Nix

![GitHub Actions status badge](https://github.com/DeterminateSystems/nuenv/actions/workflows/ci.yml/badge.svg?branch=main)

**Nuenv** is an as an alternative builder for [Nix] that uses [Nushell] instead of [Bash] as in Nix's [standard environment][stdenv].
For more information, check out [Nuenv: an experimental Nushell environment for Nix][post] on the [Determinate Systems blog][blog].

> **Warning**: Nuenv is a fun experiment and potential source of inspiration but we don't advise using it for any serious purpose just yet.

## Running the scenario

First, make sure that you have [Nix] installed with [flakes enabled][flake]. We recommend using the [Determinate Nix Installer][dni]:

```shell
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install
```

With Nix installed, you can [realise] a Nix [derivation] that uses Nuenv instead of stdenv:

```shell
nix build --print-build-logs
```

You should see build output like this:

```shell
hello-nix-nushell> >>> INFO
hello-nix-nushell> > Realising the hello-nix-nushell derivation for aarch64-darwin
hello-nix-nushell> > Running on 10 cores
hello-nix-nushell> > Using Nushell 0.77.1
hello-nix-nushell> > Declared build outputs:
hello-nix-nushell> + out
hello-nix-nushell> >>> SETUP
hello-nix-nushell> > Adding 1 package to PATH:
hello-nix-nushell> + hello-2.12.1
hello-nix-nushell> > Setting PATH
hello-nix-nushell> > Setting 1 user-supplied environment variable:
hello-nix-nushell> + MESSAGE = "Hello from Nix + Bash"
hello-nix-nushell> > Copying sources
hello-nix-nushell> > Setting 1 output environment variable:
hello-nix-nushell> + out = "/nix/store/j4xa93na112v3dlf3a1xba5v0vxkc3af-hello-nix-nushell"
hello-nix-nushell> >>> REALISATION
hello-nix-nushell> > Running build phase
hello-nix-nushell> + Running hello version 2.12.1
hello-nix-nushell> + Creating $out directory at /nix/store/j4xa93na112v3dlf3a1xba5v0vxkc3af-hello-nix-nushell/share
hello-nix-nushell> + Writing hello message to /nix/store/j4xa93na112v3dlf3a1xba5v0vxkc3af-hello-nix-nushell/share/hello.txt
hello-nix-nushell> + Substituting "Bash" for "Nushell" in /nix/store/j4xa93na112v3dlf3a1xba5v0vxkc3af-hello-nix-nushell/share/hello.txt
hello-nix-nushell> > Outputs written:
hello-nix-nushell> + out to /nix/store/j4xa93na112v3dlf3a1xba5v0vxkc3af-hello-nix-nushell
hello-nix-nushell> >>> DONE!
```

This derivation does something very straightforward: it provides a message to GNU's [hello] tool and saves the result in a text file called `hello.txt` under the `share` directory.

```shell
cat ./result/share/hello.txt
```

## How it works

The key differentiator from regular Nix here is that [realisation][realise] happens in [Nushell] scripts rather than in [Bash].
The project's [flake] in [`flake.nix`](./flake.nix) outputs a function called `mkNushellDerivation` that wraps Nix's built-in [`derivation`][derivation] function but, in contrast to [`stdenv.mkDerivation`][stdenv], uses a Nushell script as the `builder`.

More specifically:

- The [`bootstrap.nu`](./nuenv/bootstrap.nu) script performs some bootstrapping operations, such as enabling the sandbox environment to discover Nushell itself.
- The bootstrap script runs the [`builder.nu`](./nuenv/builder.nu) script, which performs the actual build.
- The [`user-env.nu`](./nuenv/user-env.nu) script provides helper functions, like [`substituteInPlace`](./nuenv/user-env.nu#L79-L94), that you can use in your derivation logic.

The Nix logic that wraps all of this is in [`nuenv.nix`](./lib/nuenv.nix#L2-L60).

## Try it out

In addition to running the [example build](#running-the-scenario) up above, you can use Nuenv to realise your own derivations.
Here's a straightforward example:

```nix
{
  inputs = {
    nixpkgs.url = "nixpkgs"; # Make sure to use a very recent Nixpkgs
    nuenv.url = "github:DeterminateSystems/nuenv";
  };

  outputs = { self, nixpkgs, nuenv }: let
    overlays = [ nuenv.overlays.default ];
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
      inherit system;
      pkgs = import nixpkgs { inherit system; };
    });
  in {
    packages = forAllSystems ({ pkgs, system }: {
      default = pkgs.nuenv.mkDerivation {
        name = "hello";
        src = ./.;
        inherit system;
        # This script is Nushell, not Bash
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
