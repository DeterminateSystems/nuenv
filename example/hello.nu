# Variables
let out = $env.out
let helloFile = "hello.txt"
let shareDir = $"($out)/share"
let helloOutputFile = $"($shareDir)/($helloFile)"
let message = $env.MESSAGE
let helloVersion = (hello --version | lines | get 0 | parse "hello (GNU Hello) {version}" | get version.0)

def blue [msg: string] { $"(ansi blue)($msg)(ansi reset)" }
def purple [msg: string] { $"(ansi purple)($msg)(ansi reset)" }

log $"Running hello version (blue $helloVersion)"

log $"Creating $out directory at (purple $shareDir)"
mkdir $shareDir

log $"Writing hello message to (purple $helloOutputFile)"
hello --greeting $message | save $helloOutputFile

ensureFileExists $helloOutputFile

log $"Substituting \"Bash\" for \"Nushell\" in (purple $helloOutputFile)"
substituteInPlace $helloOutputFile --replace "Bash" --with "Nushell"

# Docs
let docDir = $env.doc
let docFile = "docs.txt"
let docOutputFile = $"($docDir)/($docFile)"

log $"Creating $doc directory at (purple $docDir)"
mkdir $docDir

log $"Writing docs to (purple $docOutputFile)"
"Here's some usage instructions" | save $docFile

cp $docFile $docDir

ensureFileExists $docOutputFile
