$Name = "SPT Limits"

$tes3conv = "..\..\..\tes3conv\tes3conv.exe"
& $tes3conv "$Name.json" "$Name.esp" -o

if (Test-Path "$Name.zip") {
    Remove-Item "$Name.zip"
}

& "C:\Program Files\7-Zip\7z.exe" a -tzip "$Name.zip" "$Name.omwscripts" "$Name.esp" "README.md" -r "scripts\" "l10n\"
