## Values
let here = $env.PWD # Current working directory
let inputs = ($env.__nu_buildInputs | split row " ")
let numInputs = ($inputs | length)

## Helper functions

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
    echo $"Running ($name)..."

    # We need to source the envFile prior to each phase so that custom Nushell
    # commands are registered. Right now there's a single env file but in
    #$ principle there could be multiple.
    nu --commands $"source ($env.__nu_envFile); ($phase)"
  } else {
    echo $"Skipping ($name)..."
  }
}

## Provide info about the current derivation
banner "INFO"


# Display Nushell version
echo $"(ansi blue)Running Nushell ($env.__nu_nushell_version)(ansi reset)"

# Display info about the derivation
echo "Derivation info:"

{
  name: $env.name,
  src: $env.src,
  out: $env.out,
  system: $env.system,
  builder: $env.builder,
  workingDirectory: $here
} | table

## Set up the environment
banner "SETUP"

# Create the output directory (realisation fails otherwise)
echo "Creating output directory..."
mkdir $env.out

# Add buildInputs to the PATH
echo $"Adding ($numInputs) buildInputs to PATH..."
let-env PATH = ($inputs |
  each { |pkg| $"($pkg)/bin" } |
  str collect (char esep)
)

echo $env.PATH

# Copy sources
echo "Copying sources..."
cp -r $"($env.src)/**/*" $here

## The realisation process (only two phases for now, but there could be more)
banner "REALISATION"

runPhase "buildPhase" $env.buildPhase
runPhase "installPhase" $env.installPhase

## Run if realisation succeeds
banner "DONE!"

echo $"Output written to ($env.out)"
