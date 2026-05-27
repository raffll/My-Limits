Write-Host "Removing .bak and .zip files..."
Remove-Item -Force *.bak, *.zip -ErrorAction SilentlyContinue
Write-Host "Done."
