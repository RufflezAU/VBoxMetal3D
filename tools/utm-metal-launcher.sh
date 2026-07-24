#!/bin/bash
# UTMetal3D — Launch UTM with Metal GPU acceleration for QEMU
UTM_APP="$HOME/Applications/UTMetal3D.app"
METAL_LIB="$HOME/Library/UTMetal3D/UTMetalAccel.dylib"

echo "╔══════════════════════════════════════════════╗"
echo "║        UTMetal3D - Acceleration              ║"
echo "╚══════════════════════════════════════════════╝"

# Build if needed
if [ ! -f "$METAL_LIB" ]; then
    cd "$(dirname "$0")/.." && make install 2>&1 | tail -3
fi

# Check if we need to rebuild the app
if [ ! -d "$UTM_APP" ]; then
    echo "✗ UTMetal3D.app not found at $UTM_APP"
    echo "  Run: ./utm-metal.sh --install"
    exit 1
fi

echo "Launching UTMetal3D..."
echo "  Check Console.app → filter 'UTMetal3D' for trace output"
open "$UTM_APP"
