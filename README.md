# Nuenv: an experimental Nushell environment for Nix

> **Warning**: This project is a fun experiment&mdash;and perhaps a source of inspiration for
> others&mdash;but not something you should use for any serious purpose.

This repo houses an example project that uses [Nushell] as an alternative builder for [Nix] (whose standard environment uses [Bash]).

## Running the scenario

First, make sure that you have [Nix] installed. We recommend using the [Determinate Nix Installer][dni]:

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
just-experimenting> >>> INFO
just-experimenting> > Building just-experimenting
just-experimenting> > Running Nushell 0.76.0
just-experimenting> > Derivation info:
just-experimenting> ╭─────────┬────────────────────────────────────────────────────────────────────╮
just-experimenting> │ name    │ just-experimenting                                                 │
just-experimenting> │ src     │ /nix/store/2cilgykyd5si7zsgr9gi610ax2j4b7z9-j0frjj2z92ryd349b62wf0 │
just-experimenting> │         │ 9g0cwzjd71-source                                                  │
just-experimenting> │ system  │ aarch64-darwin                                                     │
just-experimenting> │ outputs │ doc, out                                                           │
just-experimenting> ╰─────────┴────────────────────────────────────────────────────────────────────╯
just-experimenting> >>> SETUP
just-experimenting> > Adding 2 packages to PATH
just-experimenting> > Copying sources
just-experimenting> >>> REALISATION
just-experimenting> > Running build phase
just-experimenting> Writing version info to /nix/store/wqr8x38rbpbna82q4nm01wl1n9iypi6h-just-experimenting/share/go-version.txt
just-experimenting> Writing help info to /nix/store/wqr8x38rbpbna82q4nm01wl1n9iypi6h-just-experimenting/share/go-help.txt
just-experimenting> Writing docs to /nix/store/jwqswcs09cgi092y4qi8534rg3fnlx53-just-experimenting-doc/share
just-experimenting> >>> DONE!
just-experimenting> > doc output written to /nix/store/jwqswcs09cgi092y4qi8534rg3fnlx53-just-experimenting-doc
just-experimenting> > out output written to /nix/store/wqr8x38rbpbna82q4nm01wl1n9iypi6h-just-experimenting
```

This derivation does something very straightforward: it runs `go version` to output the version information for the [Go] package in the environment and writes that string to a text file under the `share` directory.

```shell
cat ./result/share/go-version.txt
```

## How it works

The key differentiator from regular Nix here is that realisation happens in [Nushell] scripts rather than in [Bash]. The project's [flake] outputs a function called `mkNushellDerivation` that wraps Nix's built-in [`derivation`][derivation] function but, in contrast to [`stdenv.mkDerivation`][stdenv], uses Nushell as the `builder`, which in turn runs a [`builder.nu`](./builder.nu) script that provides the Nix environment.

## Try it out

You can use nuenv to realise your own derivations. Here's a straightforward example:

```nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/release-22.11";
    nuenv.url = "github:DeterminateSystems/nuenv";
  };

  outputs = { self, nixpkgs, nuenv }: let
    system = "x86_64-linux";
    overlays = [ nuenv.overlays.default ];
    pkgs = import nixpkgs { inherit overlays system; };
  in {
    packages.${system}.default = pkgs.nuenv.mkDerivation {
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
  };
}
```

[bash]: https://gnu.org/software/bash
[derivation]: https://zero-to-nix.com/concepts/derivations
[flake]: https://zero-to-nix.com/concepts/flakes
[dni]: https://github.com/DeterminateSystems/nix-installer
[go]: https://golang.org
[nix]: https://nixos.org
[nushell]: https://nushell.sh
[realise]: https://zero-to-nix.com/concepts/realisation
[stdenv]: https://ryantm.github.io/nixpkgs/stdenv/stdenv
