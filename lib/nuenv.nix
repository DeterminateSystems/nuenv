# The Nuenv build environment

# nixpkgs.nushell (from overlay)
nushell:

# nixpkgs.system (from overlay)
sys:

{ name                              # The name of the derivation
, src                               # The derivation's sources
, packages ? [ ]                    # Packages provided to the realisation process
, system ? sys                      # The build system
, build ? ""                        # The build phase
, debug ? true                      # Run in debug mode
, outputs ? [ "out" ]               # Outputs to provide
, envFile ? ../nuenv/user-env.nu  # Nushell environment passed to build phases
, ...                               # Catch user-supplied env vars
}@attrs:

let
  # Gather arbitrary user-supplied env vars
  reservedAttrs = [
    "build"
    "debug"
    "envFile"
    "name"
    "outputs"
    "packages"
    "src"
    "system"
    "__nu_debug"
    "__nu_extra_attrs"
    "__nu_packages"
  ];

  extraAttrs = removeAttrs attrs reservedAttrs;
in
derivation ({
  # Derivation
  inherit envFile name outputs src system;

  # Phases
  inherit build;

  # Build logic
  builder = "${nushell}/bin/nu";
  args = [ ../nuenv/builder.nu ];

  # When this is set, Nix writes the environment to a JSON file at
  # $NIX_BUILD_TOP/.attrs.json. Because Nushell can handle JSON natively, this approach
  # is generally cleaner than parsing environment variables as strings.
  __structuredAttrs = true;

  # Attributes passed to the environment (prefaced with __nu_ to avoid naming collisions)
  __nu_debug = debug;
  __nu_extra_attrs = extraAttrs;
  __nu_packages = packages;
} // extraAttrs)
