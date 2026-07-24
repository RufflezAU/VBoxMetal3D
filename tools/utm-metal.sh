#!/bin/bash
# UTMetal3D — Launch UTM with Metal GPU acceleration for QEMU
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

UTM_PATH="/Applications/UTM.app"
FW_DIR="$UTM_PATH/Contents/Frameworks"
QEMU_NAME="qemu-aarch64-softmmu"
QEMU_FW_PATH="$FW_DIR/${QEMU_NAME}.framework"
QEMU_BIN="$QEMU_FW_PATH/${QEMU_NAME}"
QEMU_BIN_ORIG="${QEMU_BIN}.original"
METAL_LIB="$HOME/Library/UTMetal3D/UTMetalAccel.dylib"
INSERT_TOOL="$HOME/Library/UTMetal3D/insert_dylib"

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        UTMetal3D - Acceleration              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"

# Build if needed
if [ ! -f "$METAL_LIB" ]; then
    cd "$(dirname "$0")/.."
    make install 2>&1 | tail -3
fi

case "${1:-}" in
    --install)
        echo -e "${BLUE}Patching QEMU binary...${NC}"
        [ ! -f "$QEMU_BIN" ] && { echo -e "${RED}✗ QEMU not found${NC}"; exit 1; }
        [ ! -f "$QEMU_BIN_ORIG" ] && cp "$QEMU_BIN" "$QEMU_BIN_ORIG"
        $INSERT_TOOL "$METAL_LIB" "$QEMU_BIN_ORIG" "$QEMU_BIN"
        codesign -f -s - "$QEMU_BIN" 2>/dev/null || true
        echo -e "${GREEN}✓ Patched — UTMetal3D active on next UTM launch${NC}"
        echo -e "${YELLOW}  Re-run after UTM updates${NC}"
        ;;
    --uninstall)
        echo -e "${BLUE}Restoring original QEMU...${NC}"
        [ -f "$QEMU_BIN_ORIG" ] && cp "$QEMU_BIN_ORIG" "$QEMU_BIN" && codesign -f -s - "$QEMU_BIN" 2>/dev/null || true
        echo -e "${GREEN}✓ Restored${NC}"
        ;;
    --status)
        if [ -f "$QEMU_BIN_ORIG" ]; then echo -e "${GREEN}✓ Patched${NC}"
        else echo -e "${YELLOW}○ Unpatched${NC}"; fi
        ;;
    *)
        echo -e "${BLUE}Usage:${NC}"
        echo "  --install    Patch QEMU binary (activates GPU acceleration)"
        echo "  --uninstall  Restore original QEMU"
        echo "  --status     Check patch status"
        echo ""
        echo -e "${YELLOW}Then launch UTM normally from /Applications${NC}"
        echo -e "${YELLOW}Check Console.app for 'UTMetal3D:' logs${NC}"
        ;;
esac
