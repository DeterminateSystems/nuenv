## Functions that can be used in derivation phases

def ensureFileExists [file: path] {
  if not ($file | path exists) {
    error make { msg: $"File not found at:\n  ($file)" }
  }
}

# Substitute all instances of the --replace string with the --with string in $1
# and output to $2.
def substitute [
  file: path,
  out: path,
  --replace (-r): string,
  --with (-w): string
] {
  ensureFileExists $file

  let orig = (open $file)
  rm $file
  let s = ($orig | str replace -a $replace $with)
  $s | save $out
}

# Substitute, in place, all instances of the --replace string with the --with
# string in $1.
def substituteInPlace [
  file: path,
  --replace (-r): string,
  --with (-w): string
] {
  substitute $file $file --replace $replace --with $with
}
