{
  # The Nuenv build function. Essentially a wrapper around Nix's core derivation function.
  mkNushellDerivation =
    nushell: # nixpkgs.nushell (from overlay)
    sys: # nixpkgs.system (from overlay)

    { name                            # The name of the derivation
    , src                             # The derivation's sources
    , packages ? [ ]                  # Packages provided to the realisation process
    , system ? sys                    # The build system
    , build ? ""                      # The build script itself
    , debug ? true                    # Run in debug mode
    , outputs ? [ "out" ]             # Outputs to provide
    , envFile ? ../nuenv/user-env.nu  # Nushell environment passed to build phases
    , ...                             # Catch user-supplied env vars
    }@attrs:

    let
      # Gather arbitrary user-supplied environment variables
      reservedAttrs = [
        "build"
        "debug"
        "envFile"
        "name"
        "outputs"
        "packages"
        "src"
        "system"
        "__nu_builder"
        "__nu_debug"
        "__nu_env"
        "__nu_extra_attrs"
        "__nu_nushell"
      ];

      extraAttrs = removeAttrs attrs reservedAttrs;
    in
    derivation ({
      # Core derivation info
      inherit envFile name outputs packages src system;

      # Realisation phases (just one for now)
      inherit build;

      # Build logic
      builder = "${nushell}/bin/nu"; # Use Nushell instead of Bash
      args = [ ../nuenv/bootstrap.nu ]; # Run a bootstrap script that then runs the builder

      # When this is set, Nix writes the environment to a JSON file at
      # $NIX_BUILD_TOP/.attrs.json. Because Nushell can handle JSON natively, this approach
      # is generally cleaner than parsing environment variables as strings.
      __structuredAttrs = true;

      # Attributes passed to the environment (prefaced with __nu_ to avoid naming collisions)
      __nu_builder = ../nuenv/builder.nu;
      __nu_debug = debug;
      __nu_env = [ ../nuenv/env.nu ];
      __nu_extra_attrs = extraAttrs;
      __nu_nushell = "${nushell}/bin/nu";
    } // extraAttrs);

  # An analogue to writeScriptBin but for Nushell rather than Bash scripts.
  mkNushellScript =
    nushell: # nixpkgs.nushell (from overlay)
    writeTextFile: # Utility function (from overlay)

    { name
    , script
    , bin ? name
    }:

    let
      nu = "${nushell}/bin/nu";
    in
    writeTextFile {
      inherit name;
      destination = "/bin/${bin}";
      text = ''
        #!${nu}

        ${script}
      '';
      executable = true;
    };
}
