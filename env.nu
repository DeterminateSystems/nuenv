## Functions that can be used in derivation phases

def ensureFileExists [
  file: path # The path to check
] {
  if not ($file | path exists) {
    error make { msg: $"File not found at:\n  ($file)" }
  }
}

# Substitute all instances of the $replace string with the $with string in <file> and output the resulting string to <out>.
def substitute [
  file: path,
  out: path,
  --replace (-r): string,
  --with (-w): string
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

# Substitute all instances of the $replace string with the $with string in <file>.
def substituteInPlace [
  file: path,
  --replace (-r): string,
  --with (-w): string
] {
  substitute $file $file --replace $replace --with $with
}
