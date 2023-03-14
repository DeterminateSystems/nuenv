# nuenv, a Nushell environment for Nix

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
just-experimenting> > Running Nushell 0.76.0
just-experimenting> > Derivation info:
just-experimenting> ╭────────┬─────────────────────────────────────────────────────────────────────╮
just-experimenting> │ name   │ just-experimenting                                                  │
just-experimenting> │ src    │ /nix/store/3prmp9ll1588hk289lm1j8ym3phrn60c-dbpaha1k7n9vfz26mivlzrf │
just-experimenting> │        │ 8k734r18l-source                                                    │
just-experimenting> │ out    │ /nix/store/5zg9x84sjqa1ig91ay8wyg9j2fp5na6v-just-experimenting      │
just-experimenting> │ system │ aarch64-darwin                                                      │
just-experimenting> ╰────────┴─────────────────────────────────────────────────────────────────────╯
just-experimenting> >>> SETUP
just-experimenting> > Adding 2 packages to PATH
just-experimenting> > Copying sources
just-experimenting> >>> REALISATION
just-experimenting> > Running build phase
just-experimenting> Writing version info to /nix/store/5zg9x84sjqa1ig91ay8wyg9j2fp5na6v-just-experimenting/share/go-version.txt
just-experimenting> Writing help info to /nix/store/5zg9x84sjqa1ig91ay8wyg9j2fp5na6v-just-experimenting/share/go-help.txt
just-experimenting> >>> DONE!
just-experimenting> > Output written to /nix/store/5zg9x84sjqa1ig91ay8wyg9j2fp5na6v-just-experimenting
```

This derivation does something very straightforward: it runs `go version` to output the version information for the [Go] package in the environment and writes that string to a text file under the `share` directory.

```shell
cat ./result/share/go-version.txt
```

## How it works

The key differentiator from regular Nix here is that realisation happens in [Nushell] scripts rather than in [Bash]. The project's [flake] outputs a function called `mkNushellDerivation` that wraps Nix's built-in [`derivation`][derivation] function but, in contrast to [`stdenv.mkDerivation`][stdenv], uses Nushell as the `builder`, which in turn runs a [`builder.nu`](./builder.nu) script that provides the Nix environment.

## Current limitations

There are a few things that you can do in the current standard environment that you can't do in this Nushell environment:

* The phases are isolated from one another, which means that you can't do things like set an environment variable in the build phase and then retrieve its value in the install phase. That's because each phase is a separate Nushell script run using `nu --commands`.
* There are only two phases: `buildPhase` and `installPhase`.

## Try it out

You can use nuenv to build derivations


```nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/release-22.11";
    nix-nushell-env.url = "github:DeterminateSystems/nix-nushell-env";
  };

  outputs = { self, nixpkgs, nix-nushell-env }: let
    system = "x86_64-linux";
    overlays = [ nix-nushell-env.overlays.default ];
    pkgs = import nixpkgs { inherit overlays system; };
  in {
    packages.${system}.default = pkgs.nuenv.mkDerivation {
      name = "hello";
      pkgs = import nixpkgs { inherit system; };
      src = ./.;
      inherit system;
      buildPhase = ''
        "Hello" | save hello.txt
      '';
      installPhase = ''
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
