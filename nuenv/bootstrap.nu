# Discover and load the .attrs.json file
let attrsJsonFile = if ($env.NIX_ATTRS_JSON_FILE | path exists) {
  $env.NIX_ATTRS_JSON_FILE
} else {
  $"($env.NIX_BUILD_TOP)/.attrs.json"
}
let attrs = open $attrsJsonFile

# Copy .nu helper files
for file in $attrs.__nu_env {
  let target = ($file | parse "{__root}-{filename}" | get filename.0)
  cp $file $target
}

# Set the PATH so that Nushell is discoverable
let-env PATH = ($attrs.__nu_nushell | parse "{root}/nu" | get root.0)

# Run the Nushell builder
nu --commands (open $attrs.__nu_builder)
