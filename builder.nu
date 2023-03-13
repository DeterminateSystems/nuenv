## Values
let here = $env.PWD # Current working directory
let packages = ($env.__nu_packages | split row " ")
let numPackages = ($packages | length)

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
    echo $"Running phase (ansi blue)($name)(ansi reset)..."

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

# Add packages to PATH
echo $"Adding ($numPackages) packages to PATH..."
let-env PATH = (
  $packages
  | each { $"($in)/bin" }   # Append /bin to each package path
  | str collect (char esep) # Collect into a single colon-separate string
)

# Copy sources
echo "Copying sources..."
cp -r $"($env.src)/**/*" $here

## The realisation process (only two phases for now, but there could be more)
banner "REALISATION"

runPhase "build" $env.build

## Run if realisation succeeds
banner "DONE!"

echo $"Output written to ($env.out)"
