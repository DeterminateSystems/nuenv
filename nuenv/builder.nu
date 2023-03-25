## Utility commands

source env.nu

def pkgs-path [pkgs: list] {
  $pkgs | each { |pkg| $"($pkg)/bin" } | str collect (char esep)
}

## Parse the build environment

# This branching is a necessary workaround for a bug in the Nix CLI fixed in
# https://github.com/NixOS/nix/pull/8053
let attrsJsonFile = if ($env.NIX_ATTRS_JSON_FILE | path exists) {
  $env.NIX_ATTRS_JSON_FILE
} else {
  $"($env.NIX_BUILD_TOP)/.attrs.json"
}

let attrs = open $attrsJsonFile
let initialPkgs = $attrs.__nu_packages

# Nushell attributes
let nushell = {
  version: (version).version, # Nushell version
  pkg: (get-pkg-root $attrs.builder), # Nushell package path
  userEnvFile: $attrs.envFile # Functions that users can apply in realisation phases
}

# Derivation attributes
let drv = {
  name: $attrs.name,
  system: $attrs.system,
  src: (glob $"($attrs.src)/**/*"), # Sources to copy into sandbox
  outputs: ($attrs.outputs | transpose key value),
  initialPackages: $initialPkgs, # Packages added by user
  # The __nu_packages environment variable is a space-separated string. This
  # pipeline converts it into a list.
  packages: (
    $initialPkgs
    | append $nushell.pkg # Add the Nushell package to the PATH
    | split row (char space)
  ),
  extraPkgs: $attrs.extraPkgs,
  rawAttrs: $attrs.__nu_extra_attrs,
  extraAttrs: ($attrs.__nu_extra_attrs | transpose key value), # Arbitrary environment variables
}

# Nix build attributes
let nix = {
  sandbox: $env.NIX_BUILD_TOP, # Sandbox directory
  store: $env.NIX_STORE, # Nix store root
  debug: (env-to-bool $attrs.__nu_debug) # Whether `debug = true` is set in the derivation
}

## Provide info about the current derivation
if $nix.debug {
  banner "INFO"

  info $"Realising the (blue $drv.name) derivation for (blue $drv.system)"

  let numCores = ($env.NIX_BUILD_CORES | into int)
  info $"Running on (blue $numCores) core(if ($numCores > 1) { "s" })"

  info $"Using Nushell (blue $nushell.version)"

  info "Declared build outputs:"
  for output in $drv.outputs { item $output.key }
}

## Set up the environment
if $nix.debug { banner "SETUP" }

# Add general packages to PATH
if not ($drv.initialPackages | is-empty) {
  let numPackages = ($drv.initialPackages | length)

  if $nix.debug {
    info $"Adding (blue $numPackages) package(plural $numPackages) to PATH:"
    for pkg in $drv.initialPackages { item (get-pkg-name $pkg) }
  }
}

# Collect all packages into a string and set PATH
if $nix.debug { info $"Setting (purple "PATH")" }

# Set user-supplied environment variables (à la FOO="bar"). Nix supplies this
# list by removing reserved attributes (name, system, build, src, system, etc.).
let numAttrs = ($drv.extraAttrs | length)

if not ($numAttrs == 0) {
  # TODO: move this into the non-Rust/etc path
  #if $nix.debug { info $"Setting (blue $numAttrs) user-supplied environment variable(plural $numAttrs):" }

  for attr in $drv.extraAttrs {
    #if $nix.debug { item $"(yellow $attr.key) = \"($attr.value)\"" }
    let-env $attr.key = $attr.value
  }
}

# Copy sources
if $nix.debug { info "Copying sources" }
for src in $drv.src { cp -r $src $nix.sandbox }

# Set environment variables for all outputs
if $nix.debug {
  let numOutputs = ($drv.outputs | length)
  info $"Setting (blue $numOutputs) output environment variable(plural $numOutputs):"
}
for output in ($drv.outputs) {
  let name = ($output | get key)
  let value = ($output | get value)

  if $nix.debug { item $"(yellow $name) = \"($value)\"" }

  let-env $name = $value
}

## The realisation process
if $nix.debug { banner "REALISATION" }

## Realisation phases (just build and install for now, more later)

# Rust
if "rust" in $drv.rawAttrs {
  let rust = $drv.rawAttrs.rust

  source rust.nu

  if $nix.debug { info "Building Rust project 🦀" }

  if $nix.debug {
    info $"Using Rust toolchain package (blue (get-pkg-name $rust.toolchain))"
    let rustTools = ls $"($rust.toolchain)/bin"
    info "Rust tools available in the toolchain:"
    for tool in $rustTools {
      item (get-pkg-bin $tool.name)
    }
  }

  let target = ($rust | get -i target | default $drv.system)

  let allRustPkgs = ($drv.packages | append $rust.toolchain | append $attrs.extraPkgs)
  let-env PATH = (pkgs-path $allRustPkgs)

  let toml = open ./Cargo.toml

  info $"Building ($toml.package.name) with cargo OK (blue cargo-version)"

  mut opts = {release: true}
  if "target" in $rust { $opts.target = $rust.target }
  if "ext" in $rust { $opts.ext = $rust.ext }
  cargo-build $opts

  mkdir $"($env.out)/bin"

  let pkgs = if "bin" in $toml {
    $toml.bin | each { |bin| $bin.name }
  } else {
    [ $toml.package.name ]
  }

  for pkg in $pkgs {
    let dir = $"target/(if "target" in $opts { $"($opts.target)/release" } else { "release" })"
    let bin = $"($pkg)(if "ext" in $opts { $".($opts.ext)" })"
    let source = $"($dir)/($bin)"
    let dest = $"($env.out)/bin/($bin)"
    info $"Copying (blue $pkg) to (purple $dest)"
    cp $source $dest
  }
} else {
  # Set PATH for package discovery
  let-env PATH = (pkgs-path $drv.packages)

  # Run a derivation phase (skip if empty)
  def runPhase [
    name: string,
  ] {
    let phase = ($attrs | get $name)

    if not ($phase | is-empty) {
      if $nix.debug { info $"Running (blue $name) phase" }
        # We need to source the envFile prior to each phase so that custom Nushell
        # commands are registered. Right now there's a single env file but in
        # principle there could be per-phase scripts.
        do --capture-errors {
          nu --env-config $nushell.userEnvFile --commands $phase

          let code = $env.LAST_EXIT_CODE

          if $code != 0 {
            exit --now $code
          }
        }
    } else {
      if $nix.debug { info $"Skipping empty (blue $name) phase" }
    }
  }

  # The available phases
  for phase in [
    "build"
  ] { runPhase $phase }
}

## Run if realisation succeeds
if $nix.debug {
  banner "DONE!"

  for output in ($drv.outputs) {
    let name = ($output | get key)
    let value = ($output | get value)
    item $"(yellow $name) output written to (purple $value)"
  }
}
