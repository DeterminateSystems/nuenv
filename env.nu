# Functions that can be used in derivation phases
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
}
