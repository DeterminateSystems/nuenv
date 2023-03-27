## Nix stuff
def attrs-json [] {
  # This branching is a necessary workaround for a bug in the Nix CLI fixed in
  # https://github.com/NixOS/nix/pull/8053
  let attrsJsonFile = if ($env.NIX_ATTRS_JSON_FILE | path exists) {
    $env.NIX_ATTRS_JSON_FILE
  } else {
    $"($env.NIX_BUILD_TOP)/.attrs.json"
  }
  open $attrsJsonFile
}

## Logging
def color [color: string, msg: string] { $"(ansi $color)($msg)(ansi reset)" }

def blue [msg: string] { color "blue" $msg }
def green [msg: string] { color "green" $msg }
def red [msg: string] { color "red" $msg }
def purple [msg: string] { color "purple" $msg }
def yellow [msg: string] { color "yellow" $msg }

def banner [text: string] { $"(red ">>>") (green $text)" }
def info [msg: string] { $"(blue ">") ($msg)" }
def item [msg: string] { $"(purple "+") ($msg)"}

# Display the <msg> in a pretty way.
def log [
  msg: string # The message to log.
] { $"(ansi green)+(ansi reset) ($msg)" }

# Misc helpers

## Add an "s" to the end of a word if n is greater than 1
def plural [n: int] { if $n > 1 { "s" } else { "" } }

## Convert a Nix Boolean into a Nushell Boolean ("1" = true, "0" = false)
def env-to-bool [var: string] {
  ($var | into int) == 1
}

def pkgs-path [pkgs: list] {
  $pkgs | each { |pkg| $"($pkg)/bin" } | str collect (char esep)
}

## Get package root
def get-pkg-root [path: path] { $path | parse "{root}/bin/{__bin}" | get root.0 }

## Get package name fro full store path
def get-pkg-name [path: path] {
  $path | parse "{__store}/{__hash}-{pkg}" | select pkg | get pkg.0
}

def get-relative-pkg-path [path: path] {
  $path | parse "{__store}/{__hash}-{__pkg}/{rel}" | get rel.0
}

def get-pkg-bin [path: path] {
  $path | parse "{__store}/{__hash}-{__pkg}/bin/{tool}" | get tool.0
}

def get-or-default [obj: record, key: string, df: any] {
  $obj | get -i $key | default $df
}

def mk-out-dir [dir: string] {
  mkdir $"($env.out)/($dir)"
}

# Run any string as a command.
def run [cmd: string] { nu --commands $cmd }

# Exit if the last operation errored
def exit-on-error [] {
  let code = $env.LAST_EXIT_CODE

  if $code != 0 {
    exit --now $code
  }
}

def run-phase [
  phases: record,
  name: string,
  envConfig: string,
  debug: bool
] {
  let phase = ($phases | get $name)

  if not ($phase | is-empty) {
    if $debug { info $"Running (blue $name) phase" }
      # We need to source the envFile prior to each phase so that custom Nushell
      # commands are registered. Right now there's a single env file but in
      # principle there could be per-phase scripts.
      do --capture-errors {
        nu --env-config $envConfig --commands $phase

        exit-on-error
      }
  } else {
    if $debug { info $"Skipping empty (blue $name) phase" }
  }
}
