## Utility commands

# Logging
def color [color: string, msg: string] { $"(ansi $color)($msg)(ansi reset)" }
def blue [msg: string] { color "blue" $msg }
def green [msg: string] { color "green" $msg }
def red [msg: string] { color "red" $msg }
def purple [msg: string] { color "purple" $msg }
def yellow [msg: string] { color "yellow" $msg }

def banner [text: string] { $"(red ">>>") (green $text)" }
def info [msg: string] { $"(blue ">") ($msg)" }
def panic [msg: string] { $"(red "ERROR") ($msg)"; exit 1 }
def item [msg: string] { $"(purple "+") ($msg)"}

def ensure-set [obj: record, key: string, objName: string] {
  if not $key in $obj {
    panic $"key (blue $key) not set in (blue $objName)"
  }
}

def plural [n: int] { if $n > 1 { "s" } else { "" } }

# Convert a Nix Boolean into a Nushell Boolean ("1" = true, "0" = false)
def env-to-bool [var: string] {
  ($var | into int) == 1
}

# Get package root
def get-pkg-root [path: path] { $path | parse "{root}/bin/{__bin}" | get root.0 }

# Get package name fro full store path
def get-pkg-name [storeRoot: path, path: path] {
  $path | parse $"($storeRoot)/{__hash}-{pkg}" | select pkg | get pkg.0
}

def get-pkg-bin [storeRoot: path, path: path] {
  $path | parse $"($storeRoot)/{__pkg}/bin/{tool}" | get tool.0
}

def attr-is-set [obj: record, key: string] {
  not ($obj | transpose name value | where name == $key | is-empty)
}

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

  if $nix.debug { info $"Adding (blue $numPackages) package(plural $numPackages) to PATH:" }

  for pkg in $drv.initialPackages {
    let name = get-pkg-name $nix.store $pkg
    if $nix.debug { item $name }
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
  if $nix.debug { info "Building Rust project 🦀" }

  let rust = $drv.rawAttrs.rust
  ensure-set $rust "toolchain" "rust"
  let toolchain = $rust.toolchain

  if $nix.debug {
    info $"Using Rust toolchain package (blue (get-pkg-name $nix.store $toolchain))"
    let rustTools = ls $"($toolchain)/bin"
    info "Rust tools available in the toolchain:"
    for tool in $rustTools {
      item (get-pkg-bin $nix.store $tool.name)
    }
  }

  let target = ($rust | get -i target | default $drv.system)

  let extraPkgs = ($rust | get -i extras | default [])
  let allRustPkgs = ($drv.packages | append $toolchain | append $extraPkgs)
  let-env PATH = (pkgs-path $allRustPkgs)

  let name = (open ./Cargo.toml | get package.name)

  let cargoVersion = (cargo --version | parse "cargo {v} {__rest}" | get v.0)
  info $"Building ($name) with cargo (blue $cargoVersion)"

  cargo build --release

  mkdir $"($env.out)/bin"
  cp $"target/release/($name)" $"($env.out)/bin/($name)"
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
