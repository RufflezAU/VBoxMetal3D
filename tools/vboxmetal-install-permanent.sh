#!/bin/bash
# VBoxMetal3D - Permanent GPU Acceleration for VirtualBox
# Usage: sudo ./vboxmetal-install-permanent.sh --install

set -e

VBOX_PLIST="/Applications/VirtualBox.app/Contents/Info.plist"
METAL_LIB="$HOME/Library/VBoxMetal3D/VBoxMetalAccel.dylib"
BACKUP_PLIST="$HOME/Library/VBoxMetal3D/Info.plist.backup"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

check_root() {
    if [ "$(id -u)" != "0" ]; then echo -e "${YELLOW}Re-run with sudo${NC}"; exit 1; fi
}

install() {
    check_root
    [ -f "$BACKUP_PLIST" ] || cp "$VBOX_PLIST" "$BACKUP_PLIST"
    [ -f "$METAL_LIB" ] || { echo -e "${RED}✗ Build first: make install${NC}"; exit 1; }

    # Modify a copy in /tmp, then copy back (PlistBuddy can't write /Applications directly on Sequoia)
    cp "$VBOX_PLIST" /tmp/Info.plist
    /usr/libexec/PlistBuddy -c 'Add :LSEnvironment dict' /tmp/Info.plist 2>/dev/null || /usr/libexec/PlistBuddy -c 'Set :LSEnvironment dict' /tmp/Info.plist 2>/dev/null
    /usr/libexec/PlistBuddy -c "Add :LSEnvironment:DYLD_INSERT_LIBRARIES string $METAL_LIB" /tmp/Info.plist 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :LSEnvironment:DYLD_INSERT_LIBRARIES $METAL_LIB" /tmp/Info.plist 2>/dev/null
    cp /tmp/Info.plist "$VBOX_PLIST"

    echo -e "${GREEN}✓ Permanent Metal acceleration installed${NC}"
    /usr/libexec/PlistBuddy -c "Print :LSEnvironment" "$VBOX_PLIST"
    echo ""
    echo "Open VirtualBox normally — GPU acceleration is always active."
}

uninstall() {
    check_root
    if [ -f "$BACKUP_PLIST" ]; then cp "$BACKUP_PLIST" "$VBOX_PLIST"; echo -e "${GREEN}✓ Restored from backup${NC}"
    else
        cp "$VBOX_PLIST" /tmp/Info.plist
        /usr/libexec/PlistBuddy -c 'Delete :LSEnvironment' /tmp/Info.plist 2>/dev/null || true
        cp /tmp/Info.plist "$VBOX_PLIST"
        echo -e "${GREEN}✓ Removed LSEnvironment${NC}"
    fi
}

status() {
    local d
    d=$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_INSERT_LIBRARIES' "$VBOX_PLIST" 2>/dev/null) && echo -e "${GREEN}✓ ACTIVE: $d${NC}" || echo -e "${YELLOW}✗ Not installed${NC}"
}

case "${1:-}" in
    --install|-i) install ;;
    --uninstall|-u) uninstall ;;
    --status|-s) status ;;
    *) echo "Usage: sudo $0 --install" ; echo "       sudo $0 --uninstall" ; echo "       $0 --status" ;;
esac
