# Nuenv: an experimental Nushell environment for Nix

![GitHub Actions status badge](https://github.com/DeterminateSystems/nuenv/actions/workflows/ci.yml/badge.svg?branch=main)

> **Warning**: This project is a fun experiment&mdash;and perhaps a source of inspiration for
> others&mdash;but not something you should use for any serious purpose.

This repo houses an example project that uses [Nushell] as an alternative builder for [Nix] (whose standard environment uses [Bash]).
For more information, check out [Nuenv: an experimental Nushell environment for Nix][post] on the [Determinate Systems blog][blog].

## Running the scenario

First, make sure that you have [Nix] installed with [flakes enabled][flake].
We recommend using the [Determinate Nix Installer][dni]:

```shell
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install
```

With Nix installed, you can [realise] a Nix [derivation]:

```shell
nix build --print-build-logs
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
The project's [flake] outputs a function called `mkNushellDerivation` that wraps Nix's built-in [`derivation`][derivation] function but, in contrast to [`stdenv.mkDerivation`][stdenv], uses Nushell as the `builder`, which in turn runs a [`builder.nu`](./builder.nu) script that provides the Nix environment.
In addition to `builder.nu`, [`env.nu`](./env.nu) provides helper functions to your realisation scripts.

## Try it out

You can use nuenv to realise your own derivations.
Here's a straightforward example:

```nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/release-22.11";
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

## Language support

[Nushell]'s expressiveness has the potential to unlock much more powerful and subtle "modules" for
derivations.

### Rust 🦀

We're currently worked on a simplified interface for [Rust] derivations as a potential alternative to
[`buildRustPackage`][rustpkg].
Here's an example:

```nix
{
  myRustPkg = pkgs.nuenv.mkRustDerivation {
    name = "my-rust-pkg";
    src = ./.;
    toolchainFile = ./rust-toolchain.toml;
    depsHash = "sha256-Y5tLXjHpfwlKrH6Pq3xEa2oxhNTF8TfK9dzw48JV5M0="; # cargo dependencies hash
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
[rust]: https://rust-lang.org
[rustpkg]: https://nixos.org/manual/nixpkgs/stable/#rust
[stdenv]: https://ryantm.github.io/nixpkgs/stdenv/stdenv
