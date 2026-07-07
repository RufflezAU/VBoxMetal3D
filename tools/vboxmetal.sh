#!/bin/bash
# VBoxMetal3D - Launch VirtualBox with Metal GPU acceleration
# Usage: ./vboxmetal.sh [--vm "VM Name"]

set -e

VBOX_PATH="/Applications/VirtualBox.app/Contents/MacOS"
METAL_LIB="$HOME/Library/VBoxMetal3D/VBoxMetalAccel.dylib"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        VBoxMetal3D - Acceleration            ║${NC}"
echo -e "${BLUE}║     Metal GPU Backend for VirtualBox         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}  To make permanent (no script needed):${NC}"
echo -e "${YELLOW}    $HOME/Library/VBoxMetal3D/vboxmetal-install-permanent.sh --install${NC}"
echo ""

# Check prerequisites
if [ ! -d "$VBOX_PATH" ]; then
    echo -e "${RED}✗ VirtualBox not found at $VBOX_PATH${NC}"
    exit 1
fi

if [ ! -f "$METAL_LIB" ]; then
    echo -e "${YELLOW}! VBoxMetal3D not installed. Building...${NC}"
    cd "$(dirname "$0")/.."
    make install 2>&1 | tail -5
    echo ""
fi

if [ ! -f "$METAL_LIB" ]; then
    echo -e "${RED}✗ Failed to build VBoxMetal3D${NC}"
    exit 1
fi

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    echo -e "${YELLOW}⚠ Warning: Not running on Apple Silicon (arch=$ARCH)${NC}"
    echo -e "${YELLOW}  Metal acceleration requires Apple Silicon (M1/M2/M3/M4)${NC}"
fi

echo -e "${GREEN}✓ Metal dylib: $METAL_LIB${NC}"
echo -e "${GREEN}✓ VirtualBox: $VBOX_PATH${NC}"
echo -e "${GREEN}✓ Architecture: $ARCH${NC}"
echo ""

# Launch
if [[ "$1" == "--vm" && -n "$2" ]]; then
    VM_NAME="$2"
    echo -e "${BLUE}Launching VM: $VM_NAME with Metal acceleration...${NC}"
    DYLD_INSERT_LIBRARIES="$METAL_LIB" \
    DYLD_FORCE_FLAT_NAMESPACE=1 \
    "$VBOX_PATH/VBoxManage" startvm "$VM_NAME" --type gui
elif [[ "$1" == "--headless" && -n "$2" ]]; then
    VM_NAME="$2"
    echo -e "${BLUE}Launching VM headless: $VM_NAME with Metal acceleration...${NC}"
    DYLD_INSERT_LIBRARIES="$METAL_LIB" \
    DYLD_FORCE_FLAT_NAMESPACE=1 \
    "$VBOX_PATH/VBoxManage" startvm "$VM_NAME" --type headless
else
    echo -e "${BLUE}Launching VirtualBox Manager with Metal acceleration...${NC}"
    echo -e "${YELLOW}  (all VMs will automatically use GPU acceleration)${NC}"
    echo ""
    DYLD_INSERT_LIBRARIES="$METAL_LIB" \
    DYLD_FORCE_FLAT_NAMESPACE=1 \
    open -W -n "$VBOX_PATH/VirtualBox" --args "$@"
fi

echo ""
echo -e "${GREEN}✓ VirtualBox session ended${NC}"
