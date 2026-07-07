#!/bin/bash
# VBoxMetal3D VRAM Unlocker
# Sets VRAM to 8GB on Apple Silicon (unified memory — no separate VRAM pool)
# Uses VBoxManage setextradata for a device-level override at VM startup.

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

VRAM_MB=8192

apply_vm() {
    local vm="$1"
    VBoxManage setextradata "$vm" "VBoxInternal/Devices/vga/0/Config/VRamSize" "$VRAM_MB" >/dev/null 2>&1
    # Also patch the .vbox XML directly
    local vbox_file
    vbox_file=$(VBoxManage showvminfo "$vm" --machinereadable 2>/dev/null | grep "^CfgFile=" | cut -d= -f2- | tr -d '"')
    if [ -f "$vbox_file" ]; then
        sed -i '' 's/VRAMSize="[0-9]*"/VRAMSize="'$VRAM_MB'"/' "$vbox_file" 2>/dev/null || true
    fi
    echo -e "${GREEN}✓ $vm → ${VRAM_MB}MB VRAM${NC}"
}

case "${1:-}" in
    --vm|-m)
        [ -z "$2" ] && { echo "Usage: $0 --vm \"VM Name\""; exit 1; }
        apply_vm "$2"
        ;;
    --all|-a)
        echo -e "${YELLOW}Setting all VMs to ${VRAM_MB}MB VRAM...${NC}"
        VBoxManage list vms 2>/dev/null | while IFS='"' read -r name uuid; do
            [ -n "$name" ] && apply_vm "$name"
        done
        echo -e "${GREEN}Done. New VMs can be set with: $0 --vm \"VM Name\"${NC}"
        ;;
    --list|-l)
        echo -e "${BLUE}VMs:${NC}"
        VBoxManage list vms 2>/dev/null | sed 's/^/  /' || echo "  (none)"
        ;;
    *)
        echo "VBoxMetal3D VRAM Unlocker — 8GB on Apple Silicon unified memory"
        echo ""
        echo "Usage:"
        echo "  $0 --vm \"VM Name\"     Set one VM to ${VRAM_MB}MB VRAM"
        echo "  $0 --all               Set ALL VMs to ${VRAM_MB}MB VRAM"
        echo "  $0 --list              List VMs"
        echo ""
        echo "The override activates at VM startup. GUI slider still shows 256MB"
        echo "(compiled Qt limit), but the device model uses ${VRAM_MB}MB at runtime."
        echo ""
        echo "Run once per VM (or --all) — then just use the Metal Dock launcher."
        ;;
esac
