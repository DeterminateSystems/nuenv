# Variables
let out = $env.out
let share = $"($out)/share"
let outputFile = $"($share)/hello.txt"

log $"Creating output directory at ($share)"
mkdir $share

log $"Writing hello message to ($outputFile)"
$env.MESSAGE | save $outputFile

log "Substituting Bash for Nushell"
substituteInPlace $outputFile --replace "Bash" --with "Nushell"
