let share = $"($env.out)/share"
mkdir $share

let versionFile = $"($share)/go-version.txt"
echo $"Writing version info to ($versionFile)"
go version | save $versionFile

let helpFile = $"($share)/go-help.txt"
echo $"Writing help info to ($helpFile)"
go help | save $helpFile

[$versionFile $helpFile] | each {|f|
  substituteInPlace $f --replace "go" --with "golang"
}

let docOut = $"($env.doc)/share"
mkdir $docOut

echo $"Writing docs to ($docOut)"
"Here is the documentation" | save $"($docOut)/docs.txt"
