let-env out = $env.out
let nushellVersion = $env.NUSHELL_VERSION

# Helper functions
def banner [text: string] {
  echo $">>> (ansi green)($text)(ansi reset)"
}


# Info about the derivation
banner "INFO"

# Display Nushell version
echo $"(ansi blue)Running Nushell ($env.NUSHELL_VERSION)(ansi reset)"

# Display info about the derivation
echo $"Derivation info:"

{
  name: $env.name,
  src: $env.src,
  system: $env.system,
  builder: $env.builder
} | table

banner "SETUP"

# Create the output directory
echo "Creating output directory..."
mkdir $env.out

# Add buildInputs to the PATH
echo "Adding buildInputs to PATH..."
let-env PATH = ($env.buildInputs | split row " " | each { |pkg| $"($pkg)/bin" } | str join ":")

banner "REALISATION"

if $env.buildPhase != "" {
  echo "Running buildPhase..."
  nu -c $env.buildPhase
} else {
  echo "Skipping buildPhase"
}

if $env.installPhase != "" {
  echo "Running installPhase..."
  nu -c $env.installPhase
} else {
  echo "Skipping installPhase"
}

banner "DONE!"

echo $"Output written to ($env.out)"
