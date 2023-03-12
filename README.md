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
write-go-version> >>> INFO
write-go-version> Running Nushell 0.76.0
write-go-version> Derivation info:
write-go-version> ╭─────────┬────────────────────────────────────────────────────────────────────╮
write-go-version> │ name    │ write-go-version                                                   │
write-go-version> │ src     │ /nix/store/l1k6rd7m4sidp1yan2l2lzhbiwq6g93p-lj6bwc6jr9yxq15m2m7ckx │
write-go-version> │         │ sw7p22snww-source                                                  │
write-go-version> │ system  │ aarch64-darwin                                                     │
write-go-version> │ builder │ /nix/store/5qc87alpnz5lynm3hk5sw5y23sg59ba2-nushell-0.76.0/bin/nu  │
write-go-version> ╰─────────┴────────────────────────────────────────────────────────────────────╯
write-go-version> >>> SETUP
write-go-version> Creating output directory...
write-go-version> Adding 2 packages to PATH...
write-go-version> Copying sources...
write-go-version> >>> REALISATION
write-go-version> Running buildPhase...
write-go-version> Writing version info to go-version.txt
write-go-version> Writing help info to go-help.txt
write-go-version> Running installPhase...
write-go-version> >>> DONE!
write-go-version> Output written to /nix/store/43znvcx0s50ihn0glvyf2djg6dpnqcjy-write-go-version
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
