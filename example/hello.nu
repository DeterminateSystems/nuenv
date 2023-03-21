# Variables
let out = $env.out
let share = $"($out)/share"
let outputFile = $"($share)/hello.txt"
let message = $env.MESSAGE
let helloVersion = (hello --version | lines | get 0 | parse "hello (GNU Hello) {version}" | get version.0)

def blue [msg: string] { $"(ansi blue)($msg)(ansi reset)" }
def purple [msg: string] { $"(ansi light_purple)($msg)(ansi reset)" }

log $"Running hello version (blue $helloVersion)"

log $"Creating output directory at (purple $share)"
mkdir $share

log $"Writing hello message to (purple $outputFile)"
hello --greeting $message | save $outputFile

ensureFileExists $outputFile

log $"Substituting \"Bash\" for \"Nushell\" in (purple $outputFile)"
substituteInPlace $outputFile --replace "Bash" --with "Nushell"
