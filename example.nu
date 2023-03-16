# Variables
let out = $env.out
let pony = "caesar"
let share = $"($out)/share"
let outputFile = "hello.txt"
let thought = "Realising Nix derivations with Bash"

# Setup
log $"Creating output directory at ($out)"
mkdir $share

# Build
log $"Writing dreamy equine thoughts to ($outputFile)"
$thought | ponythink --pony $pony | save $outputFile

# Install
log $"Copying ($outputFile) to ($out)"
cp $outputFile $share

substituteInPlace $outputFile --replace "Bash" --with "Nushell"

log "Done!"
