#!/bin/bash
# VBoxMetal3D - Permanent GPU Acceleration for VirtualBox
# Creates a native wrapper app in ~/Applications/ that always uses Metal.

set -e

WRAPPER_APP="$HOME/Applications/VBoxMetal3D.app"
METAL_LIB="$HOME/Library/VBoxMetal3D/VBoxMetalAccel.dylib"
LAUNCHER_SRC="$HOME/projects/VBoxMetal3D/tools/launcher.c"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

install() {
    if [ ! -f "$METAL_LIB" ]; then
        echo -e "${YELLOW}✗ Build Metal backend first: cd ~/projects/VBoxMetal3D && make install${NC}"
        exit 1
    fi
    if [ ! -f "$LAUNCHER_SRC" ]; then
        echo -e "${RED}✗ launcher.c not found. Reclone from GitHub.${NC}"
        exit 1
    fi

    # Compile the launcher
    clang -target arm64-apple-macos15.0 -O2 -o /tmp/VBoxMetal3D_launcher "$LAUNCHER_SRC"

    # Create/update the wrapper app
    mkdir -p "$WRAPPER_APP/Contents/MacOS"
    cp /tmp/VBoxMetal3D_launcher "$WRAPPER_APP/Contents/MacOS/VBoxMetal3D"

    cat > "$WRAPPER_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>VBoxMetal3D</string>
    <key>CFBundleIdentifier</key>
    <string>com.vboxmetal.launcher</string>
    <key>CFBundleName</key>
    <string>VirtualBox (Metal)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>virtualbox</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

    # Try to copy VirtualBox icon
    if [ -f /Applications/VirtualBox.app/Contents/Resources/virtualbox.icns ]; then
        mkdir -p "$WRAPPER_APP/Contents/Resources"
        cp /Applications/VirtualBox.app/Contents/Resources/virtualbox.icns "$WRAPPER_APP/Contents/Resources/"
    fi

    echo -e "${GREEN}✓ VirtualBox (Metal).app created at:${NC}"
    echo "  $WRAPPER_APP"
    echo ""
    echo -e "${YELLOW}Add to Dock:${NC}"
    echo "  open $WRAPPER_APP"
    echo "  (then right-click the icon → Options → Keep in Dock)"
    echo ""
    echo -e "${BLUE}Now just click the Dock icon to launch with Metal GPU.${NC}"
    echo ""
    echo -e "${YELLOW}To verify it works, check Console.app for "VBoxMetal3D:" messages.${NC}"
}

uninstall() {
    rm -rf "$WRAPPER_APP"
    echo -e "${GREEN}✓ Wrapper app removed${NC}"
    echo "Remove the Dock icon manually (right-click → Options → Remove from Dock)"
}

status() {
    if [ -d "$WRAPPER_APP" ]; then
        echo -e "${GREEN}✓ Wrapper app installed at:${NC}"
        echo "  $WRAPPER_APP"
        if [ -f "$METAL_LIB" ]; then
            echo -e "${GREEN}✓ dylib: $METAL_LIB${NC}"
        else
            echo -e "${RED}✗ dylib missing${NC}"
        fi
    else
        echo -e "${YELLOW}✗ Not installed. Run: $0 --install${NC}"
    fi
}

case "${1:-}" in
    --install|-i) install ;;
    --uninstall|-u) uninstall ;;
    --status|-s) status ;;
    *) echo "Usage: $0 --install   (create Metal wrapper app)" ; echo "       $0 --uninstall (remove)" ; echo "       $0 --status    (check)" ;;
esac
