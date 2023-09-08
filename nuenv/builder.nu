## Utility commands

source env.nu

## Parse the build environment

# This branching is a necessary workaround for a bug in the Nix CLI fixed in
# https://github.com/NixOS/nix/pull/8053
let attrsJsonFile = if ($env.NIX_ATTRS_JSON_FILE | path exists) {
  $env.NIX_ATTRS_JSON_FILE
} else {
  $"($env.NIX_BUILD_TOP)/.attrs.json"
}

let attrs = (open $attrsJsonFile)
let initialPkgs = $attrs.packages

# Nushell attributes
let nushell = {
  version: (version).version, # Nushell version
  pkg: (getPkgRoot $attrs.builder), # Nushell package path
  userEnvFile: $attrs.envFile # Functions that users can apply in realisation phases
}

# Derivation attributes
let drv = {
  name: $attrs.name, # The name of the derivation
  system: $attrs.system, # The build system
  src: (glob $"($attrs.src)/**/*"), # Sources to copy into the sandbox
  outputs: ($attrs.outputs | transpose key value),
  initialPackages: $initialPkgs, # Packages added by user
  # The packages environment variable is a space-separated string. This
  # pipeline converts it into a list.
  packages: (
    $initialPkgs
    | append $nushell.pkg # Add the Nushell package to the PATH
    | split row (char space)
  ),
  extraAttrs: ($attrs.__nu_extra_attrs | transpose key value), # Arbitrary environment variables
}

# Nix build attributes
let nix = {
  sandbox: $env.NIX_BUILD_TOP, # Sandbox directory
  store: $env.NIX_STORE, # Nix store root
  debug: (envToBool $attrs.__nu_debug) # Whether `debug = true` is set in the derivation
}

## Provide info about the current derivation
if $nix.debug {
  banner "INFO"

  info $"Realising the (blue $drv.name) derivation for (blue $drv.system)"

  let numCores = ($env.NIX_BUILD_CORES | into int)
  info $"Running on (blue $numCores) core(if ($numCores > 1) { "s" })"

  info $"Using Nushell (blue $nushell.version)"

  # Nix throws an error if the outputs array is empty, so we don't need to handle that case
  info "Declared build outputs:"
  for output in $drv.outputs { item $output.key }
}

## Set up the environment
if $nix.debug { banner "SETUP" }

# Log user-added packages if debug is set
if (not ($drv.initialPackages | is-empty)) and $nix.debug {
  let numPackages = ($drv.initialPackages | length)

  info $"Adding (blue ($numPackages | into string)) package(plural $numPackages) to PATH:"

  for pkg in $drv.initialPackages {
    let name = (getPkgName $nix.store $pkg)
    item $name
  }
}

# Collect all packages into a string and set the PATH
if $nix.debug { info $"Setting (purple "PATH")" }

let packagesPath = (
  $drv.packages                  # List of strings
  | each { |pkg| $"($pkg)/bin" } # Append /bin to each package path
  | str join (char esep)      # Collect into a single colon-separated string
)
let-env PATH = $packagesPath

# Set user-supplied environment variables (à la FOO="bar"). Nix supplies this
# list by removing reserved attributes (name, system, build, src, system, etc.).
let numAttrs = ($drv.extraAttrs | length)

if $numAttrs != 0 {
  if $nix.debug { info $"Setting (blue ($numAttrs | into string)) user-supplied environment variable(plural $numAttrs):" }

  for attr in $drv.extraAttrs {
    if $nix.debug { item $"(yellow $attr.key) = \"($attr.value)\"" }
    let-env $attr.key = $attr.value
  }
}

# Copy sources into sandbox
if $nix.debug { info "Copying sources" }
for src in $drv.src { cp -r $src $nix.sandbox }

# Set environment variables for all outputs
if $nix.debug {
  let numOutputs = ($drv.outputs | length)
  info $"Setting (blue ($numOutputs | into string)) output environment variable(plural $numOutputs):"
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

# Run a derivation phase (skip if empty)
def runPhase [
  name: string,
] {
  if $name in $attrs {
    let phase = ($attrs | get $name)

    if $nix.debug { info $"Running (blue $name) phase" }

    # We need to source the envFile prior to each phase so that custom Nushell
    # commands are registered. Right now there's a single env file but in
    # principle there could be per-phase scripts.
    do --capture-errors {
      nu --log-level warn --env-config $nushell.userEnvFile --commands $phase

      let exitCode = $env.LAST_EXIT_CODE

      if ($exitCode | into int) != 0 {
        exit $exitCode
      }
    } | default {} # To prevent `empty list` being displayed (until Nushell fixes this)
  } else if $nix.debug { info $"Skipping empty (blue $name) phase" }
}

# The available phases (just one for now)
let phases = [ "build" ]

for phase in $phases { runPhase $phase }

## Run if realisation succeeds
if $nix.debug {
  info "Outputs written:"

  for output in ($drv.outputs) {
    let name = ($output | get key)
    let value = ($output | get value)
    item $"(yellow $name) to (purple $value)"
  }

  banner "DONE!"
}
