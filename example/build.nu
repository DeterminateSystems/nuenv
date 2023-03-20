# Variables
let out = $env.out
let share = $"($out)/share"
let outputFile = $"($share)/happy-thought.txt"
let pony = "caesar"
let thought = "Realising Nix derivations with Bash"

# Demonstrate that user-suppled environment variables work
log $"User-supplied environment variable: BOOPER=($env.BOOPER)"

# Setup
log $"Creating output directory at ($out)"
mkdir $share

# Build
log $"Writing dreamy equine thoughts to (relativePath $outputFile)"
$thought | ponythink --pony $pony | save $outputFile

# Install
log $"Substituting text in (relativePath $outputFile)"

substituteInPlace $outputFile --replace "Bash" --with "Nushell"
