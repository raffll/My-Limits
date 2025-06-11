#!/bin/bash

NAME="Stats and Potions Limit"

if [ -e "$NAME.zip" ]; then
	rm "$NAME.zip"
fi

"C:\Program Files\7-Zip\7z.exe" a -tzip "$NAME.zip" "*.esp" "*.omwscripts" README.md -x!*.omwscripts.esp -r scripts\
