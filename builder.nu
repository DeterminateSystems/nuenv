## Helper functions

# Splashy, colored banner text
def banner [text: string] {
  echo $"(ansi red)>>>(ansi reset) (ansi green)($text)(ansi reset)"
}

# Run a derivation phase (skip if empty)
def runPhase [name: string, phase: string] {
  if $phase != "" {
    echo $"Running ($name)Phase..."

    # We need to source the envFile prior to each phase so that custom Nushell commands get
    # registered. Right now there's a single env file but in principle there could be multiple.
    nu --commands $"source ($env.__envFile); ($phase)"
  } else {
    echo $"Skipping ($name)Phase..."
  }
}

## Provide info about the current derivation
banner "INFO"

# Display Nushell version
echo $"(ansi blue)Running Nushell ($env.__nushell_version)(ansi reset)"

# Display info about the derivation
echo $"Derivation info:"

{
  name: $env.name,
  src: $env.src,
  system: $env.system,
  builder: $env.builder
} | table

## Set up the environment
banner "SETUP"

# Create the output directory (realisation fails otherwise)
echo "Creating output directory..."
mkdir $env.out

# Add buildInputs to the PATH
echo "Adding buildInputs to PATH..."
let-env PATH = ($env.__buildInputs | split row " " | each { |pkg| $"($pkg)/bin" } | str join ":")

## The realisation process (only two phases for now, but there could be more)
banner "REALISATION"

runPhase "build" $env.buildPhase
runPhase "install" $env.installPhase

## Run if realisation succeeds
banner "DONE!"

echo $"Output written to ($env.out)"
