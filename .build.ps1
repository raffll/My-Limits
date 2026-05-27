$Name = "Stats Potions Training Limits"

if (Test-Path "$Name.zip") {
    Remove-Item "$Name.zip"
}

& "C:\Program Files\7-Zip\7z.exe" a -tzip "$Name.zip" "*.esp" "*.omwscripts" "README.md" "-x!*.omwscripts.esp" -r "scripts\"
