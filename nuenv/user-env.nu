## Functions that can be used in derivation phases

# Get the relative path of <path> with respect to either the Nix store root or the build directory
# root.
def relativePath [
  path: path # The path to extract
] {
  # If <path> is in the temporary build directory, this returns
  # /($env.NIX_BUILD_TOP)/<__dir>/<path>. If <path> is in the Nix store, this returns
  # /($env.NIX_STORE)/<__pkg>/<path>. The default value for $env.NIX_BUILD_TOP is /private/tmp while
  # the default for $env.NIX_STORE is /nix/store; both can be changed via Nix configuration.

  if ($path | str starts-with $env.NIX_BUILD_TOP) {
    $path | parse $"($env.NIX_BUILD_TOP)/{path}" | select path | get path.0
  } else if ($path | str starts-with $env.NIX_STORE) {
    $path | parse $"($env.NIX_STORE)/{_pkg}/{path}" | select path | get path.0
  } else {
    $path
  }
}

# Display the <msg> in a pretty way.
def log [
  msg: string # The message to log.
] {
  print $"(ansi green)+(ansi reset) ($msg)"
}

# Output the error <msg> in a flashy way.
def err [
  msg: string # The error string to log
] {
  print $"(ansi red)ERROR(ansi reset): ($msg)"
}

# Check that <file> exists and throw an error if it doesn't.
def ensureFileExists [
  file: path # The path to check for existence
] {
  if not (($file | path exists) and true) {
    let relativeFilePath = (relativePath $file)
    err $"File not found at: (ansi red)($relativeFilePath)(ansi reset)"
    exit 1
  }
}

# Substitute all instances of <replace> in <file> with <with> and output the resulting string to
# <out>.
def substitute [
  file: path, # The target file
  out: path, # The output file
  --replace (-r): string, # The string to replace in <file>
  --with (-w): string, # The replacement for <replace>
] {
  ensureFileExists $file
  # Store the initial file contents in a variable
  let orig = (open $file)
  # Delete the original file
  rm $file
  # Build a new string with the substitution applied
  let s = ($orig | str replace -a $replace $with)
  # Write the new string to the target file
  $s | save $out
}

# Substitute all instances of the string <replace> in <file> with the string <with>.
def substituteInPlace [
  ...files: path, # The target file
  --replace (-r): string, # The string to replace in <file>
  --with (-w): string # The replacement for <replace>
] {
  for $file in $files { substitute $file $file --replace $replace --with $with }
}

# Display Nuenv-specific commands.
def nuenvCommands [] {
  help commands
  | where command_type == "custom"
  | where not (name in ["create_left_prompt" "create_right_prompt" "nuenvCommands"])
  | select name usage
}
