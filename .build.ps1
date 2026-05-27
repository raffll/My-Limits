$Name = "SPT Limits"

if (Test-Path "$Name.zip") {
    Remove-Item "$Name.zip"
}

& "C:\Program Files\7-Zip\7z.exe" a -tzip "$Name.zip" "SPT Limits.omwscripts" "README.md" -r "scripts\" -r "l10n\"
