#!/bin/bash
# VBoxMetal3D - Permanent GPU Acceleration for VirtualBox
# Patches VirtualBox.app Info.plist to always load the Metal backend.
# Run with: sudo ./vboxmetal-install-permanent.sh --install

set -e

VBOX_APP="/Applications/VirtualBox.app"
VBOX_PLIST="$VBOX_APP/Contents/Info.plist"
METAL_LIB="$HOME/Library/VBoxMetal3D/VBoxMetalAccel.dylib"
BACKUP_PLIST="$HOME/Library/VBoxMetal3D/Info.plist.backup"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Must run as root to modify /Applications
need_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${YELLOW}Admin access required to modify $VBOX_APP${NC}"
        echo -e "${YELLOW}Re-run with sudo: sudo $0 $*${NC}"
        exit 1
    fi
}

install() {
    need_root "$@"

    if [ ! -d "$VBOX_APP" ]; then
        echo -e "${RED}✗ VirtualBox not found at $VBOX_APP${NC}"; exit 1
    fi
    if [ ! -f "$METAL_LIB" ]; then
        echo -e "${YELLOW}✗ VBoxMetalAccel.dylib not found${NC}"
        echo "  Build it first: cd ~/projects/VBoxMetal3D && make install"
        exit 1
    fi
    if [ ! -f "$BACKUP_PLIST" ]; then
        cp "$VBOX_PLIST" "$BACKUP_PLIST"
        echo -e "${GREEN}✓ Backed up original Info.plist to $BACKUP_PLIST${NC}"
    fi

    /usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$VBOX_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSEnvironment:DYLD_INSERT_LIBRARIES string $METAL_LIB" "$VBOX_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :LSEnvironment:DYLD_INSERT_LIBRARIES $METAL_LIB" "$VBOX_PLIST" 2>/dev/null

    echo -e "${GREEN}✓ Permanent Metal acceleration installed${NC}"
    echo ""
    /usr/libexec/PlistBuddy -c "Print :LSEnvironment" "$VBOX_PLIST"
    echo ""
    echo -e "${BLUE}Now VirtualBox always uses Metal GPU acceleration:${NC}"
    echo "  • Open VirtualBox normally - click the icon"
    echo "  • All VM processes inherit automatically"
    echo ""
    echo -e "${YELLOW}Verify with:${NC}"
    echo "  log stream --predicate 'eventMessage contains \"VBoxMetal3D\"'"
    echo "  # Then open VirtualBox"
}

uninstall() {
    need_root "$@"

    if [ -f "$BACKUP_PLIST" ]; then
        cp "$BACKUP_PLIST" "$VBOX_PLIST"
        echo -e "${GREEN}✓ Restored original Info.plist from backup${NC}"
    else
        /usr/libexec/PlistBuddy -c "Delete :LSEnvironment" "$VBOX_PLIST" 2>/dev/null || true
        echo -e "${GREEN}✓ Removed LSEnvironment${NC}"
    fi
    echo -e "${GREEN}✓ VirtualBox reverted to default${NC}"
}

status() {
    local active
    active=$(/usr/libexec/PlistBuddy -c "Print :LSEnvironment:DYLD_INSERT_LIBRARIES" "$VBOX_PLIST" 2>/dev/null || true)
    if [ -n "$active" ]; then
        echo -e "${GREEN}✓ Permanent acceleration: ACTIVE${NC}"
        echo "  $active"
    else
        echo -e "${YELLOW}✗ Permanent acceleration: NOT installed${NC}"
        echo "  Install: sudo $0 --install"
        echo "  One-time: ~/Library/VBoxMetal3D/vboxmetal.sh"
    fi
    if [ -f "$METAL_LIB" ]; then echo -e "${GREEN}✓ dylib present${NC}"; fi
    if [ -f "$BACKUP_PLIST" ]; then echo -e "${GREEN}✓ Backup: $BACKUP_PLIST${NC}"; fi
}

case "${1:-}" in
    --install|-i) install "$@" ;;
    --uninstall|-u) uninstall ;;
    --status|-s) status ;;
    *)
        echo "VBoxMetal3D - Permanent GPU Acceleration for VirtualBox"
        echo ""
        echo "Usage:"
        echo "  sudo $0 --install     Enable (always on)"
        echo "  sudo $0 --uninstall   Disable (restore default)"
        echo "  $0 --status          Check status"
        echo ""
        echo "After install, just open VirtualBox normally."
        exit 0
        ;;
esac
