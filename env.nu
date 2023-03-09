## Functions that can be used in derivation phases

# Substitute all instances of the --replace string with the --with string in $1
# and output to $2.
def substitute [
  file: path,
  out: path,
  --replace (-r): string,
  --with (-w): string
] {
  (open $file | str replace -a $replace $with) | save $out
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
