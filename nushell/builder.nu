## Utility commands

# Logging
def color [color: string, msg: string] { $"(ansi $color)($msg)(ansi reset)" }
def blue [msg: string] { color "blue" $msg }
def green [msg: string] { color "green" $msg }
def red [msg: string] { color "red" $msg }
def purple [msg: string] { color "purple" $msg }

def banner [text: string] { $"(red ">>>") (green $text)" }
def info [msg: string] { $"(blue ">") ($msg)" }
def item [msg: string] { $"(purple "+") ($msg)"}

# Convert a Nix Boolean into a Nushell Boolean ("1" = true, "0" = false)
def env-to-bool [var: string] {
  ($var | into int) == 1
}

def get-pkg-root [path: path] {
  $path | parse "{root}/bin/{__bin}" | get root.0
}

## Parse the build environment

let attrsJsonFile = $env.NIX_ATTRS_JSON_FILE # Created by __structuredAttrs = true
let attrs = open $attrsJsonFile
let initialPkgs = $attrs.__nu_packages

# Nushell attributes
let nushell = {
  version: (version).version, # Nushell version
  pkg: (get-pkg-root $attrs.builder), # Nushell package path
  userEnvFile: $attrs.__nu_user_env_file # Functions that users can apply in realisation phases
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
  info $"Using Nushell (blue $nushell.version)"

  info "Declared build outputs:"
  for output in $drv.outputs { item $output.key }
}

## Set up the environment
if $nix.debug { banner "SETUP" }

# Add packages to PATH
# Total number of packages added to the env by the user
let numPackages = ($drv.initialPackages | length)
let pkgString = $"package(if $numPackages > 1 or $numPackages == 0 { "s" })"
if $nix.debug {
  info $"Adding (blue $numPackages) ($pkgString) to PATH:"

  for pkg in $drv.initialPackages {
    let name = ($pkg | parse $"($nix.store)/{__hash}-{pkg}" | select pkg | get pkg.0)
    item $name
  }
}

# Collect all packages into a string and set PATH
if $nix.debug { info $"Setting (purple "PATH")" }

let packagesPath = (
  $drv.packages                  # List of strings
  | each { |pkg| $"($pkg)/bin" } # Append /bin to each package path
  | str collect (char esep)      # Collect into a single colon-separate string
)
let-env PATH = $packagesPath

# Set user-supplied environment variables (à la FOO="bar")
let extraAttrsList = $drv.extraAttrs
if $nix.debug {
  let numAttrs = ($extraAttrsList | length)
  if not ($numAttrs | is-empty) {
    info $"Setting ($numAttrs) user-supplied environment variables"

    for attr in $extraAttrsList {
      item $"($attr.key)=($attr.value)"
    }
  }
}

for attr in $drv.extraAttrs {
  let-env $attr.key = $attr.value
}

# Copy sources
if $nix.debug { info "Copying sources" }
for src in $drv.src { cp -r $src $nix.sandbox }

# Create output directories and set environment variables for all outputs
if $nix.debug { info "Creating output directories" }
for output in ($drv.outputs) {
  let name = ($output | get key)
  let value = ($output | get value)
  let-env $name = $value
  mkdir $value # Otherwise realisation fails
}

## The realisation process
if $nix.debug { banner "REALISATION" }

## Realisation phases (just build and install for now, more later)

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
      nu --config $nushell.userEnvFile --commands $phase
  } else {
    if $nix.debug { info $"Skipping empty (blue $name) phase" }
  }
}

# The available phases
for phase in [
  "build"
] { runPhase $phase }

## Run if realisation succeeds
if $nix.debug {
  banner "DONE!"

  for output in ($drv.outputs) {
    let name = ($output | get key)
    let value = ($output | get value)
    info $"(purple $name) output written to ($value)"
  }
}