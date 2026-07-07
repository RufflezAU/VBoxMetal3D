#!/bin/bash
# VBoxMetal3D Uninstaller

set -e

METAL_DIR="$HOME/Library/VBoxMetal3D"

if [ -d "$METAL_DIR" ]; then
    echo "Removing VBoxMetal3D from $METAL_DIR..."
    rm -rf "$METAL_DIR"
    echo "✓ VBoxMetal3D uninstalled"
else
    echo "VBoxMetal3D is not installed"
fi
