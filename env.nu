## Functions that can be used in derivation phases

# Substitute all instances of the --replace string with the --with string in --file.
def substituteInPlace [
  --replace (-r): string,
  --with (-w): string,
  --file (-f): string,
] {
  if $replace == null {
    error make {msg: "You must specify text to replace"}
  }

  if $with == null {
    error make {msg: "You must specify replacement text"}
  }

  if $file == null {
    error make {msg: "You must specifiy a file"}
  }

  echo $'Substituting "($with)" for "($replace)" in ($file)'

  (cat $file | str replace -a $replace $with) | save $file
}
