## Functions that can be used in derivation phases

# Substitute all instances of the --replace string with the --with string in $1
# and output to $2.
def substitute [
  file: path,
  out: path,
  --replace (-r): string,
  --with (-w): string
] {
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
