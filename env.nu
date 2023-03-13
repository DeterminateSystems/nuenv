## Functions that can be used in derivation phases

# Get the relative path of <path> extracted from /private/tmp/<dir>/<path>.
def get-file-relative-path [
  path: path # The path to extract
] {
  let top = $env.NIX_BUILD_TOP

  $path | parse $"($top)/{path}" | select path | get path.0
}

def err [
  msg: string # The error string to log
] {
  echo $"\n(ansi red)ERROR(ansi reset): ($msg)\n"
  exit 1
}

# Check that <file> exists and throw an error if not
def ensureFileExists [
  file: path, # The path to check for existence
] {
  if not ($file | path exists) {
    let relativeFilePath = get-file-relative-path $file
    err $"File not found at: ($relativeFilePath)"
  }
}

# Substitute all instances of <replace> in <file> with <with> and output the resulting string to <out>.
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

# Substitute all instances of <replace> in <file> with <with>.
def substituteInPlace [
  file: path, # The target file
  --replace (-r): string, # The string to replace in <file>
  --with (-w): string # The replacement for <replace>
] {
  substitute $file $file --replace $replace --with $with
}
