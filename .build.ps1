$Name = "SPT Limits"

$tes3conv = "..\Remastered Rebalance Redux\tes3conv\tes3conv.exe"
& $tes3conv "SPT.json" "SPT.esp" -o

if (Test-Path "$Name.zip") {
    Remove-Item "$Name.zip"
}

& "C:\Program Files\7-Zip\7z.exe" a -tzip "$Name.zip" "SPT Limits.omwscripts" "SPT.esp" "README.md" -r "scripts\" "l10n\"
