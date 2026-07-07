#!/bin/bash
# VBoxMetal3D - Permanent GPU Acceleration for VirtualBox
# Patches VirtualBox.app Info.plist to always load the Metal backend.
# Usage: sudo ./vboxmetal-install-permanent.sh --install

set -e

VBOX_APP="/Applications/VirtualBox.app"
VBOX_PLIST="$VBOX_APP/Contents/Info.plist"
METAL_LIB="$HOME/Library/VBoxMetal3D/VBoxMetalAccel.dylib"
BACKUP_PLIST="$HOME/Library/VBoxMetal3D/Info.plist.backup"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

install() {
    if [ ! -d "$VBOX_APP" ]; then echo -e "${RED}✗ VirtualBox not found${NC}"; exit 1; fi
    if [ ! -f "$METAL_LIB" ]; then echo -e "${RED}✗ Build first: cd ~/projects/VBoxMetal3D && make install${NC}"; exit 1; fi

    [ -f "$BACKUP_PLIST" ] || cp "$VBOX_PLIST" "$BACKUP_PLIST"

    /usr/libexec/PlistBuddy -c 'Add :LSEnvironment dict' "$VBOX_PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c 'Set :LSEnvironment dict' "$VBOX_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSEnvironment:DYLD_INSERT_LIBRARIES string $METAL_LIB" "$VBOX_PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :LSEnvironment:DYLD_INSERT_LIBRARIES $METAL_LIB" "$VBOX_PLIST" 2>/dev/null

    echo -e "${GREEN}✓ Permanent Metal acceleration installed${NC}"
    /usr/libexec/PlistBuddy -c 'Print :LSEnvironment' "$VBOX_PLIST"
    echo ""
    echo "Open VirtualBox normally — GPU acceleration is always active."
}

uninstall() {
    if [ -f "$BACKUP_PLIST" ]; then cp "$BACKUP_PLIST" "$VBOX_PLIST"; else /usr/libexec/PlistBuddy -c 'Delete :LSEnvironment' "$VBOX_PLIST" 2>/dev/null || true; fi
    echo -e "${GREEN}✓ Reverted to default${NC}"
}

status() {
    local d
    d=$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_INSERT_LIBRARIES' "$VBOX_PLIST" 2>/dev/null) && echo -e "${GREEN}✓ ACTIVE: $d${NC}" || echo -e "${YELLOW}✗ Not installed${NC}"
}

case "${1:-}" in
    --install|-i)
        if [ "$(id -u)" != "0" ]; then echo -e "${YELLOW}Re-run with sudo: sudo $0 --install${NC}"; exit 1; fi
        install
        ;;
    --uninstall|-u)
        [ "$(id -u)" = "0" ] || { echo -e "${YELLOW}Re-run with sudo: sudo $0 --uninstall${NC}"; exit 1; }
        uninstall
        ;;
    --status|-s) status ;;
    *) echo "Usage: sudo $0 --install   (enable permanently)" ; echo "       sudo $0 --uninstall (disable)" ; echo "       $0 --status   (check)" ;;
esac
