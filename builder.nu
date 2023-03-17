## Helper functions
# Convert a Nix Boolean into a Nushell Boolean ("1" = true, "0" = false)
def env-to-bool [var: string] {
  ($var | into int) == 1
}

## Parse the build environment
# General Nix values
let attrsJsonFile = $env.NIX_ATTRS_JSON_FILE # Created by __structuredAttrs = true
let attrs = open $attrsJsonFile

let sandbox = $env.NIX_BUILD_TOP # Sandbox directory
let drvName = $attrs.name
let drvSrc = $attrs.src
let drvSystem = $attrs.system
let drvBuildScript = $attrs.build
let nixStore = $env.NIX_STORE
let outputs = ($attrs.outputs | transpose)
let nushellVersion = (version).version # Nushell version
let nushellPkg = ($attrs.builder | parse $"{root}/bin/nu" | get root.0) # Nushell package path
let initialPackages = $attrs.__nu_packages # Packages that aren't Nushell
let packages = (
  # The __nu_packages environment variable is a space-separated string. This
  # pipeline converts it into a list.
  $initialPackages
  | append $nushellPkg # Add the Nushell package to the PATH
  | split row (char space)
)
let envFile = $attrs.__nu_envFile
let debug = env-to-bool $attrs.__nu_debug

## Helper values
# Total # of packages added to the env by the user
let numPackages = ($initialPackages | length)

let packagesPath = (
  $packages                      # List of strings
  | each { |pkg| $"($pkg)/bin" } # Append /bin to each package path
  | str collect (char esep)      # Collect into a single colon-separate string
)

let srcs = glob $"($drvSrc)/**/*" # Sources to copy into sandbox

## Helper commands

# Logging
def color [color: string, msg: string] { $"(ansi $color)($msg)(ansi reset)" }
def blue [msg: string] { color "blue" $msg }
def green [msg: string] { color "green" $msg }
def red [msg: string] { color "red" $msg }
def purple [msg: string] { color "purple" $msg }

def banner [text: string] { $"(red ">>>") (green $text)" }
def info [msg: string] { $"(blue ">") ($msg)" }

# Run a derivation phase (skip if empty)
def runPhase [
  name: string,
  phase: string,
] {
  if $phase != "" {
    if $debug { info $"Running (blue $name) phase" }

    # We need to source the envFile prior to each phase so that custom Nushell
    # commands are registered. Right now there's a single env file but in
    # principle there could be per-phase scripts.
    nu --config $envFile --commands $phase
  } else {
    if $debug { info $"Skipping (blue $name) phase" }
  }
}

## Provide info about the current derivation
if $debug {
  banner "INFO"

  info $"Realising the (blue $drvName) derivation"

  # Display Nushell version
  info $"Using Nushell (blue $nushellVersion)"

  info "Derivation info:"

  {
    name: $drvName,
    system: $drvSystem,
    outputs: ($outputs | each { $in | get column0 } | str collect ", "),
  } | table
}

## Set up the environment
if $debug { banner "SETUP" }

# Create the output directory (realisation fails otherwise)
#mkdir $drvOut

# Add packages to PATH
let pkgString = $"package(if $numPackages > 1 or $numPackages == 0 { "s" })"

if $debug { info $"Adding (blue $numPackages) ($pkgString) to PATH:" }

let-env PATH = $packagesPath

# Copy sources
if $debug { info "Copying sources" }

$srcs | each { |src| cp -r $src $sandbox }

# The realisation process
if $debug { banner "REALISATION" }

# Create output directories and set environment variables for all outputs
for output in ($outputs) {
  let name = ($output | get column0)
  let value = ($output | get column1)
  let-env $name = $value
  mkdir $value
}

runPhase "build" $drvBuildScript

## Run if realisation succeeds
if $debug {
  banner "DONE!"

  for output in ($outputs) {
    let name = ($output | get column0)
    let value = ($output | get column1)
    info $"(purple $name) output written to ($value)"
  }
}
