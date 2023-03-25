# Logging

def color [color: string, msg: string] { $"(ansi $color)($msg)(ansi reset)" }

def blue [msg: string] { color "blue" $msg }
def green [msg: string] { color "green" $msg }
def red [msg: string] { color "red" $msg }
def purple [msg: string] { color "purple" $msg }
def yellow [msg: string] { color "yellow" $msg }

def banner [text: string] { $"(red ">>>") (green $text)" }
def info [msg: string] { $"(blue ">") ($msg)" }
def item [msg: string] { $"(purple "+") ($msg)"}

# Misc helpers

## Add an "s" to the end of a word if n is greater than 1
def plural [n: int] { if $n > 1 { "s" } else { "" } }

## Convert a Nix Boolean into a Nushell Boolean ("1" = true, "0" = false)
def env-to-bool [var: string] {
  ($var | into int) == 1
}

## Get package root
def get-pkg-root [path: path] { $path | parse "{root}/bin/{__bin}" | get root.0 }

## Get package name fro full store path
def get-pkg-name [path: path] {
  $path | parse "{__store}/{__hash}-{pkg}" | select pkg | get pkg.0
}

def get-pkg-bin [path: path] {
  $path | parse "{__store}/{__hash}-{__pkg}/bin/{tool}" | get tool.0
}

def get-or-default [obj: record, key: string, df: any] {
  $obj | get -i $key | default $df
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
