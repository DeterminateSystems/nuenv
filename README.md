# Nuenv: an experimental Nushell environment for Nix

![GitHub Actions status badge](https://github.com/DeterminateSystems/nuenv/actions/workflows/ci.yml/badge.svg?branch=main)

> **Warning**: This project is a fun experiment&mdash;and perhaps a source of inspiration for
> others&mdash;but not something you should use for any serious purpose.

This repo houses an example project that uses [Nushell] as an alternative builder for [Nix] (whose standard environment uses [Bash]).
For more information, check out [Nuenv: an experimental Nushell environment for Nix][post] on the [Determinate Systems blog][blog].

## Running the scenario

First, make sure that you have [Nix] installed with [flakes enabled][flake]. We recommend using the [Determinate Nix Installer][dni]:

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
cow-says-hello> >>> INFO
cow-says-hello> > Building cow-says-hello
cow-says-hello> > Running Nushell 0.76.0
cow-says-hello> > Derivation info:
cow-says-hello> ╭─────────┬────────────────╮
cow-says-hello> │ name    │ cow-says-hello │
cow-says-hello> │ system  │ aarch64-darwin │
cow-says-hello> │ outputs │ out            │
cow-says-hello> ╰─────────┴────────────────╯
cow-says-hello> >>> SETUP
cow-says-hello> > Adding 2 packages to PATH:
cow-says-hello> > Copying sources
cow-says-hello> >>> REALISATION
cow-says-hello> > Running build phase
cow-says-hello> + Creating output directory at /nix/store/6gfxzzh342l0i38gswdc87pvg9n344bj-cow-says-hello
cow-says-hello> + Writing dreamy equine thoughts to hello.txt
cow-says-hello> + Copying hello.txt to /nix/store/6gfxzzh342l0i38gswdc87pvg9n344bj-cow-says-hello
cow-says-hello> + Done!
cow-says-hello> >>> DONE!
cow-says-hello> > out output written to /nix/store/6gfxzzh342l0i38gswdc87pvg9n344bj-cow-says-hello
```

This derivation does something very straightforward: it provides a message to [ponythink] and saves the result in a text file called `happy-thought.txt` under the `share` directory.

```shell
cat ./result/share/hello.txt
```

## How it works

The key differentiator from regular Nix here is that realisation happens in [Nushell] scripts rather than in [Bash]. The project's [flake] outputs a function called `mkNushellDerivation` that wraps Nix's built-in [`derivation`][derivation] function but, in contrast to [`stdenv.mkDerivation`][stdenv], uses Nushell as the `builder`, which in turn runs a [`builder.nu`](./builder.nu) script that provides the Nix environment. In addition to `builder.nu`, [`env.nu`](./env.nu) provides helper functions to your realisation scripts.

## Try it out

You can use nuenv to realise your own derivations. Here's a straightforward example:

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
          "Hello" | save hello.txt
          let out = $"($env.out)/share"
          mkdir $out
          cp hello.txt $out
        '';
      };
    });
  };
}
```

[bash]: https://gnu.org/software/bash
[blog]: https://determinate.systems/posts
[derivation]: https://zero-to-nix.com/concepts/derivations
[flake]: https://zero-to-nix.com/concepts/flakes
[dni]: https://github.com/DeterminateSystems/nix-installer
[nix]: https://nixos.org
[nushell]: https://nushell.sh
[ponythink]: https://github.com/erkin/ponysay
[post]: https://determinate.systems/posts/nuenv
[realise]: https://zero-to-nix.com/concepts/realisation
[stdenv]: https://ryantm.github.io/nixpkgs/stdenv/stdenv
