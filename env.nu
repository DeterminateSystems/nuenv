## Functions that can be used in derivation phases

def err [
  msg: string, # The error string to log
] {
  error make { msg: $"(ansi red)x(ansi reset) ($msg)" }
}

def ensureFileExists [
  file: path, # The path to check for existence
] {
  if not ($file | path exists) {
    err $"File not found at:\n  ($file)"
  }
}

# Substitute all instances of <replace> in <file> with <with> and output the resulting string to <out>.
def substitute [
  file: path, # The target file
  out: path, # The output file
  --replace (-r): string, # The string to replace in <file>
  --with (-w): string # The replacement for <replace>
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
