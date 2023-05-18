## Bootstrap script
# This script performs any necessary setup before the builder.nu script is run.

# Discover and load the .attrs.json file, which supplies Nuenv with all the
# information it needs to realise the derivation.
let here = $env.NIX_BUILD_TOP

let attrsJsonFile = if ($env.NIX_ATTRS_JSON_FILE | path exists) {
  $env.NIX_ATTRS_JSON_FILE
} else {
  $"($here)/.attrs.json"
}
let attrs = (open $attrsJsonFile)

# Copy all .nu helper files into the sandbox
for file in $attrs.__nu_env {
  let filename = ($file | parse "{__root}-{filename}" | get filename.0)
  let target = $"($here)/($filename)"
  cp $file $target
}

# Set the PATH so that Nushell itself is discoverable. The PATH will be
# overwritten later.
let-env PATH = ($attrs.__nu_nushell | parse "{root}/nu" | get root.0)

# Run the Nushell builder
nu --commands (open $attrs.__nu_builder)
