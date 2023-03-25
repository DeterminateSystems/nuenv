def cargo-build [r: record] {
  mut flags = []
  if ("release" in $r and $r.release) { $flags = ($flags | append {flag: "release"}) }
  if ("target" in $r) { $flags = ($flags | append {flag: "target", value: $r.target}) }
  let flagStr = (
    $flags
    | each { |f| $"--($f.flag)(if ("value" in $f) { $"(char space)($f.value)" })" }
    | str collect (char space)
  )
  let cargoCmd = $"cargo build ($flagStr)"
  run $cargoCmd
}

def cargo-version [] {
  cargo --version | parse "cargo {v} {__rest}" | get v.0
}
