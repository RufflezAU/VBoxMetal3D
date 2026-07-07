# VBoxMetal3D Patches

These patches raise VirtualBox's video memory cap from 256MB to 8192MB
for Apple Silicon unified memory and fix the GUI slider to show the full range.

## How to apply

```bash
# 1. Get the VirtualBox source matching your installed version
curl -L https://download.virtualbox.org/virtualbox/7.2.12/VirtualBox-7.2.12.tar.bz2 -o /tmp/vbox.tar.bz2
cd /tmp && tar xf vbox.tar.bz2

# 2. Apply patches
cd /tmp/VirtualBox-7.2.12
patch -p1 < /path/to/0001-vram-unlock-8192mb.patch

# 3. Build (this takes ~1-2 hours):
#    Follow https://www.virtualbox.org/wiki/Linux%20build%20instructions
#    On macOS, the kBuild build system is used:
./configure --disable-hardening
source ./env.sh
kmk

# 4. Replace the built dylibs in your /Applications/VirtualBox.app:
#    (the specific dylibs depend on what changed)
```

> **Note**: Building VirtualBox from source requires the full build toolchain
> (Xcode, Python, kBuild, etc.) and takes significant time. The build output
> replaces `VBoxSVC` and `UICommon.dylib` with the patched versions.

## Alternative: ExtraData override (no build needed)

If building from source is too involved, you can use VBoxManage to inject
a device-level override that works at VM startup:

```bash
VBoxManage setextradata "Your VM" "VBoxInternal/Devices/vga/0/Config/VRamSize" 8192
```

This bypasses the GUI and COM validation entirely — the device model reads
this value at VM startup. The GUI still shows 256MB but the VM uses 8192MB.

## Files changed

1. **`src/VBox/Main/xml/VirtualBox-settings.xsd`** — `<xsd:maxInclusive value="256"/>` → `8192`
2. **`src/VBox/Frontends/VirtualBox/src/settings/editors/UIVideoMemoryEditor.cpp`** — hardcoded `256` → `m_iMaxVRAM`
3. **`src/VBox/Main/src-server/PlatformPropertiesImpl.cpp`** — remove `SchemaDefs::MaxGuestVRAM` clamp
