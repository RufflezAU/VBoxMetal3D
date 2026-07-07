#!/bin/bash
# VBoxMetal3D VRAM Unlocker
# Uses VBoxManage setextradata to set VRAM beyond 256MB cap.
# On Apple Silicon, all RAM is unified — no separate VRAM pool.
# These internal config keys bypass the GUI validation.

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

SANITY_MAX=8192  # 8GB safe max for 32-bit field compatibility

set_vram() {
    local vm="$1"
    local mb="$2"

    if [ "$mb" -lt 256 ] || [ "$mb" -gt "$SANITY_MAX" ]; then
        echo -e "${RED}VRAM must be 256-${SANITY_MAX}MB${NC}"
        exit 1
    fi

    VBoxManage setextradata "$vm" "VBoxInternal/Devices/vga/0/Config/VRamSize" "$mb" 2>/dev/null
    VBoxManage setextradata "$vm" "VBoxInternal/Devices/pcbios/0/Config/VramSize" "$mb" 2>/dev/null
    # Also patch the standard Display setting via direct XML manipulation for the guest SVGA driver
    local vbox_file
    vbox_file=$(VBoxManage showvminfo "$vm" --machinereadable 2>/dev/null | grep "^CfgFile=" | cut -d= -f2- | tr -d '"')
    if [ -f "$vbox_file" ]; then
        cp "$vbox_file" "${vbox_file}.vram.backup" 2>/dev/null || true
        sed -i '' "s/VRAMSize=\"[0-9]*\"/VRAMSize=\"$mb\"/" "$vbox_file" 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ $vm: VRAM set to ${mb}MB${NC}"
    echo -e "${YELLOW}  (GUI may still show 256MB limit — internal override active)${NC}"
}

show() {
    local vm="$1"
    echo -e "${BLUE}$vm VRAM:${NC}"
    local ext
    ext=$(VBoxManage getextradata "$vm" "VBoxInternal/Devices/vga/0/Config/VRamSize" 2>/dev/null | grep "Value:" | cut -d: -f2-)
    if [ -n "$ext" ]; then
        echo -e "${GREEN}  Active: ${ext}MB (via setextradata)${NC}"
    fi
    local vbox_file
    vbox_file=$(VBoxManage showvminfo "$vm" --machinereadable 2>/dev/null | grep "^CfgFile=" | cut -d= -f2- | tr -d '"')
    if [ -f "$vbox_file" ]; then
        local xml_val
        xml_val=$(grep -o 'VRAMSize="[0-9]*"' "$vbox_file" 2>/dev/null | grep -o '[0-9]*')
        [ -n "$xml_val" ] && echo "  Display VRAMSize: ${xml_val}MB"
    fi
    echo "  VBoxManage reports:"
    VBoxManage showvminfo "$vm" --machinereadable 2>/dev/null | grep "vram" | head -3
}

reset_vram() {
    local vm="$1"
    VBoxManage setextradata "$vm" "VBoxInternal/Devices/vga/0/Config/VRamSize" 2>/dev/null
    VBoxManage setextradata "$vm" "VBoxInternal/Devices/pcbios/0/Config/VramSize" 2>/dev/null
    local vbox_file
    vbox_file=$(VBoxManage showvminfo "$vm" --machinereadable 2>/dev/null | grep "^CfgFile=" | cut -d= -f2- | tr -d '"')
    if [ -f "${vbox_file}.vram.backup" ]; then
        cp "${vbox_file}.vram.backup" "$vbox_file"
    fi
    echo -e "${GREEN}✓ $vm: VRAM reset to default${NC}"
}

case "${1:-}" in
    --set|-s)
        [ -z "$3" ] && { echo "Usage: $0 --set \"VM Name\" <MB>"; exit 1; }
        set_vram "$2" "$3"
        ;;
    --show|-i)
        [ -z "$2" ] && { echo "Usage: $0 --show \"VM Name\""; exit 1; }
        show "$2"
        ;;
    --reset|-r)
        [ -z "$2" ] && { echo "Usage: $0 --reset \"VM Name\""; exit 1; }
        reset_vram "$2"
        ;;
    --list|-l)
        echo -e "${BLUE}Available VMs:${NC}"
        VBoxManage list vms 2>/dev/null | sed 's/^/  /'
        ;;
    *)
        echo "VBoxMetal3D VRAM Unlocker"
        echo ""
        echo "Sets VRAM beyond 256MB cap on Apple Silicon unified memory."
        echo ""
        echo "Usage:"
        echo "  $0 --set \"VM Name\" 2048     Set VRAM to 2GB"
        echo "  $0 --set \"VM Name\" 4096     Set VRAM to 4GB"
        echo "  $0 --set \"VM Name\" 8192     Set VRAM to 8GB"
        echo "  $0 --show \"VM Name\"         Show current VRAM"
        echo "  $0 --reset \"VM Name\"        Reset to default"
        echo "  $0 --list                    List VMs"
        echo ""
        echo "Recommendations (M4 24GB):"
        echo "  2048MB — general gaming"
        echo "  4096MB — modern games"
        echo "  8192MB — heavy workloads"
        ;;
esac
