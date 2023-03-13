## Parse the build environment

# General Nix values
let sandbox = $env.NIX_BUILD_TOP # Sandbox directory
let drvName = $env.name
let drvSrc = $env.src
let drvOut = $env.out
let drvSystem = $env.system
let drvBuildScript = $env.build

# Nushell-specific values
let packages = ($env.__nu_packages | split row " ")
let nushellVersion = $env.__nu_nushell_version
let envFile = $env.__nu_envFile

# Helper values
let numPackages = ($packages | length)

### Helper functions

# Splashy, colored banner text
def banner [text: string] {
  echo $"(ansi red)>>>(ansi reset) (ansi green)($text)(ansi reset)"
}

# Run a derivation phase (skip if empty)
def runPhase [
  name: string,
  phase: string,
] {
  if $phase != "" {
    echo $"Running phase (ansi blue)($name)(ansi reset)..."

    # We need to source the envFile prior to each phase so that custom Nushell
    # commands are registered. Right now there's a single env file but in
    #$ principle there could be multiple.
    nu --commands $"source ($envFile); ($phase)"
  } else {
    echo $"Skipping ($name)..."
  }
}

## Provide info about the current derivation
banner "INFO"

# Display Nushell version
echo $"(ansi blue)Running Nushell ($nushellVersion)(ansi reset)"

# Display info about the derivation
echo "Derivation info:"

{
  name: $drvName,
  src: $drvSrc,
  out: $drvOut,
  system: $drvSystem
} | table

## Set up the environment
banner "SETUP"

# Create the output directory (realisation fails otherwise)
echo $"Creating output directory at ($drvOut)"
mkdir $drvOut

# Add packages to PATH
echo $"Adding (ansi teal)($numPackages)(ansi reset) packages to PATH..."
let-env PATH = (
  $packages
  | each { $"($in)/bin" }   # Append /bin to each package path
  | str collect (char esep) # Collect into a single colon-separate string
)

# Copy sources
echo "Copying sources..."

let srcs = glob $"($drvSrc)/**/*"
$srcs | each { |src| cp -r $src $sandbox }

## The realisation process (only two phases for now, but there could be more)
banner "REALISATION"

runPhase "build" $drvBuildScript

## Run if realisation succeeds
banner "DONE!"

echo $"Output written to ($drvOut)"
