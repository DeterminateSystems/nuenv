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

def display-rust-tools [toolchain: string] {
  let rustTools = ls $"($toolchain)/bin"
  info "Rust tools available in the toolchain:"
  for tool in $rustTools {
    item (get-pkg-bin $tool.name)
  }
}

# Get the binary outputs for the project. By default this is a single-item list
# of package.name but if you supply a [[bin]] list in Cargo.toml you can have
# multiple.
def get-bins [toml: record] {
  if "bin" in $toml {
    $toml.bin | each { |bin| $bin.name }
  } else {
    [ $toml.package.name ]
  }
}
