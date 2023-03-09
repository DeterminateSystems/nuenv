# nuenv, a Nushell environment for Nix

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

```log
write-go-version> >>> INFO
write-go-version> Running Nushell 0.71.0
write-go-version> Derivation info:
write-go-version> ╭─────────┬────────────────────────────────────────────────────────────────────╮
write-go-version> │ name    │ write-go-version                                                   │
write-go-version> │ src     │ /nix/store/ymkzvjd5k8w9f3xxx84s7grgcgjfww21-y7s2xi8c7zbkr5i69c1hbq │
write-go-version> │         │ qzpgd3lbkj-source                                                  │
write-go-version> │ system  │ aarch64-darwin                                                     │
write-go-version> │ builder │ /nix/store/1rkir3hqk5lvcqd5lkiq628w0xrl17px-nushell-0.71.0/bin/nu  │
write-go-version> ╰─────────┴────────────────────────────────────────────────────────────────────╯
write-go-version> >>> SETUP
write-go-version> Creating output directory...
write-go-version> Adding buildInputs to PATH...
write-go-version> >>> REALISATION
write-go-version> Running buildPhase...
write-go-version> Running installPhase...
write-go-version> >>> DONE!
write-go-version> Output written to /nix/store/fv5261iww83vi8dm6q5qsgl3i6h3kf4q-write-go-version
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

## Try it out

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
