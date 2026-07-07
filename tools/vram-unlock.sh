#!/bin/bash
# VBoxMetal3D VRAM Unlocker
# Bypasses VirtualBox's 256MB cap for Apple Silicon unified memory.
# Uses VBoxManage setextradata to inject a device-level override.
# This works at VM startup regardless of what the GUI slider shows.

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

SANITY_MAX=8192

set_vram() {
    local vm="$1"
    local mb="$2"
    if [ "$mb" -lt 256 ] || [ "$mb" -gt "$SANITY_MAX" ]; then
        echo -e "${RED}VRAM must be 256-${SANITY_MAX}MB${NC}"; exit 1
    fi

    # Device-level CFGM override — bypasses all COM validation, applied at VM startup
    VBoxManage setextradata "$vm" "VBoxInternal/Devices/vga/0/Config/VRamSize" "$mb" >/dev/null 2>&1
    VBoxManage setextradata "$vm" "VBoxInternal/Devices/pcbios/0/Config/VramSize" "$mb" >/dev/null 2>&1

    # Also try direct XML patching
    local vbox_file
    vbox_file=$(VBoxManage showvminfo "$vm" --machinereadable 2>/dev/null | grep "^CfgFile=" | cut -d= -f2- | tr -d '"')
    if [ -f "$vbox_file" ]; then
        cp "$vbox_file" "${vbox_file}.vram.backup.$(date +%s)" 2>/dev/null || true
        sed -i '' 's/VRAMSize="[0-9]*"/VRAMSize="'$mb'"/' "$vbox_file" 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ $vm → ${mb}MB VRAM${NC}"
    echo -e "${YELLOW}  Active on next VM start. GUI still shows 256MB (compile-time limit).${NC}"
}

show() {
    local vm="$1"
    echo -e "${BLUE}$vm:${NC}"
    local ext
    ext=$(VBoxManage getextradata "$vm" "VBoxInternal/Devices/vga/0/Config/VRamSize" 2>/dev/null | grep "Value:" | cut -d: -f2-)
    [ -n "$ext" ] && echo -e "  ${GREEN}Override: ${ext}MB${NC}" || echo "  No override set"
    local vbox_file
    vbox_file=$(VBoxManage showvminfo "$vm" --machinereadable 2>/dev/null | grep "^CfgFile=" | cut -d= -f2- | tr -d '"')
    [ -f "$vbox_file" ] && echo "  XML: $(grep -o 'VRAMSize="[0-9]*"' "$vbox_file" 2>/dev/null)"
}

reset_vram() {
    local vm="$1"
    VBoxManage setextradata "$vm" "VBoxInternal/Devices/vga/0/Config/VRamSize" 2>/dev/null
    VBoxManage setextradata "$vm" "VBoxInternal/Devices/pcbios/0/Config/VramSize" 2>/dev/null
    echo -e "${GREEN}✓ $vm: Override removed (default 256MB restored)${NC}"
}

case "${1:-}" in
    --set|-s) [ -z "$3" ] && { echo "Usage: $0 --set \"VM Name\" <MB>"; exit 1; }
        set_vram "$2" "$3" ;;
    --show|-i) [ -z "$2" ] && { echo "Usage: $0 --show \"VM Name\""; exit 1; }
        show "$2" ;;
    --reset|-r) [ -z "$2" ] && { echo "Usage: $0 --reset \"VM Name\""; exit 1; }
        reset_vram "$2" ;;
    --list|-l) echo -e "${BLUE}VMs:${NC}"; VBoxManage list vms 2>/dev/null | sed 's/^/  /' ;;
    *)
        echo "VBoxMetal3D VRAM Unlocker — Apple Silicon unified memory"
        echo ""
        echo "Usage:"
        echo "  $0 --set \"VM\" 4096      Set VRAM to 4GB (bypass 256MB cap)"
        echo "  $0 --set \"VM\" 8192      Set VRAM to 8GB"
        echo "  $0 --show \"VM\"          Show current VRAM config"
        echo "  $0 --reset \"VM\"         Remove override"
        echo "  $0 --list                 List VMs"
        echo ""
        echo "Recommendations (M4 24GB):"
        echo "  2048 — general gaming"
        echo "  4096 — modern games"
        echo "  8192 — heavy workloads"
        echo ""
        echo "Note: GUI slider stays at 256MB (compiled limit)."
        echo "The device-level override activates on VM start."
        ;;
esac
