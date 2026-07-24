#!/bin/bash
# Launch UTMetal3D — UTM with Metal GPU acceleration
set -e
UTM_APP="$HOME/Applications/UTMetal3D.app"
if [ ! -d "$UTM_APP" ]; then
    echo "✗ UT Metal3D app not found. Run 'make install' first."
    exit 1
fi
echo "Launching UTMetal3D..."
open "$UTM_APP"
echo "✓ Launched. Check Console.app for 'UTMetal3D:' logs."
