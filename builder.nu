## Parse the build environment

# General Nix values
let attrsJsonFile = $env.NIX_ATTRS_JSON_FILE # Created by __structuredAttrs = true
let attrs = open $attrsJsonFile

let sandbox = $env.NIX_BUILD_TOP # Sandbox directory
let drvName = $attrs.name
let drvSrc = $attrs.src
let drvOut = $attrs.outputs.out
let drvSystem = $attrs.system
let drvBuildScript = $attrs.build
let nixStore = $env.NIX_STORE

# Helpers for build scripts
let-env out = $attrs.outputs.out

# Nushell-specific values
let packages = (
  # The __nu_packages environment variable is a space-separate string. This
  # pipeline converts into it into a list.
  $attrs.__nu_packages
  | split row (char space)
)

let nushellVersion = $attrs.__nu_nushell_version
let envFile = $attrs.__nu_envFile
let debug = ($attrs.__nu_debug | into int) == 1

# Helper values
let numPackages = ($packages | length) # Total # of packages added to the env

let packagesPath = (
  $packages                      # List of strings
  | each { |pkg| $"($pkg)/bin" } # Append /bin to each package path
  | str collect (char esep)      # Collect into a single colon-separate string
)

let srcs = glob $"($drvSrc)/**/*" # Sources to copy into sandbox

## Helper commands

# Logging
def color [color: string, msg: string] { echo $"(ansi $color)($msg)(ansi reset)" }
def blue [msg: string] { color "blue" $msg }
def green [msg: string] { color "green" $msg }
def purple [msg: string] { color "purple" $msg }
def red [msg: string] { color "red" $msg }

def banner [text: string] { echo $"(red ">>>") (green $text)" }
def info [msg: string] { echo $"(blue ">") ($msg)" }

# Run a derivation phase (skip if empty)
def runPhase [
  name: string,
  phase: string,
] {
  if $phase != "" {
    if $debug { info $"Running (purple $name) phase" }

    # We need to source the envFile prior to each phase so that custom Nushell
    # commands are registered. Right now there's a single env file but in
    # principle there could be per-phase scripts.
    nu --config $envFile --commands $phase
  } else {
    if $debug { info $"Skipping (purple $name) phase" }
  }
}

## Provide info about the current derivation
if $debug {
  banner "INFO"

  # Display Nushell version
  info $"Running Nushell (blue $nushellVersion)"

  info "Derivation info:"

  {
    name: $drvName,
    src: $drvSrc,
    out: $drvOut,
    system: $drvSystem
  } | table
}

## Set up the environment
if $debug { banner "SETUP" }

# Create the output directory (realisation fails otherwise)
mkdir $drvOut

# Add packages to PATH
if $debug { info $"Adding (blue $numPackages) packages to PATH" }

let-env PATH = $packagesPath

# Copy sources
if $debug { info "Copying sources" }

$srcs | each { |src| cp -r $src $sandbox }

## The realisation process (only two phases for now, but there could be more)
if $debug { banner "REALISATION" }

runPhase "build" $drvBuildScript

## Run if realisation succeeds
if $debug {
  banner "DONE!"

  info $"Output written to ($drvOut)"
}
