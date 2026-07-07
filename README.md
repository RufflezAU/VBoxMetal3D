# VBoxMetal3D

Metal GPU acceleration for VirtualBox on Apple Silicon (M1–M4).

Replaces VirtualBox's CPU-bound software rendering with native Metal GPU access.
Intercepts 52 OpenGL/CGL calls and redirects them to the M4's GPU cores.

Also unlocks the 256MB video memory cap — on Apple Silicon, all RAM is unified,
there's no separate VRAM pool. The slider shows values up to 8192MB.

## Quick start

```bash
# 1. Build
git clone https://github.com/RufflezAU/VBoxMetal3D.git
cd VBoxMetal3D
make install

# 2. Install permanent Dock launcher
chmod +x tools/vboxmetal-install-permanent.sh
./tools/vboxmetal-install-permanent.sh --install

# 3. Open the wrapper app, then keep it in Dock
open ~/Applications/VBoxMetal3D.app
# Right-click Dock icon → Options → Keep in Dock
```

That's it. Click the Dock icon to launch VirtualBox with GPU acceleration.

## What it does

| Feature | How |
|---------|-----|
| **GPU rendering** | All OpenGL calls from VirtualBox are intercepted via dyld and routed to Metal. The M4's GPU cores handle rendering instead of CPU. |
| **VRAM slider** | The slider shows 256MB–8192MB. The cap is removed by intercepting `GetMaxGuestVRAM` and `GetSupportedVRAMRange` at runtime. |
| **Zero-copy** | Apple Silicon's unified memory means no buffer transfers between CPU and GPU. |

## Verify it's working

Open **Console.app** and filter for `VBoxMetal3D`. When you launch via the Dock
wrapper, you should see:

```
VBoxMetal3D: Interposed 57 OpenGL→Metal functions
VBoxMetal3D: Device: Apple M4
```

## Files

```
VBoxMetal3D/
├── src/                    # Metal rendering engine
│   ├── MetalInterpose.mm   # 57 OpenGL→Metal function hooks
│   ├── MetalContext.mm     # MTLDevice, MTLCommandQueue
│   ├── MetalDisplay.mm     # CAMetalLayer display pipeline
│   ├── MetalTexture.mm     # GL→Metal texture conversion
│   └── MetalRenderer.mm    # GPU compute/blit operations
├── tools/
│   ├── vboxmetal.sh                # One-time terminal launcher
│   ├── vboxmetal-install-permanent.sh  # Creates Dock wrapper
│   └── launcher.c                  # Native wrapper app source
├── shaders/
│   └── VBoxMetalShaders.metal      # Metal shaders (runtime compiled)
├── patches/
│   ├── 0001-vram-unlock-8192mb.patch   # Source patch for VRAM cap
│   └── configure-fixes/                # Build system fixes for macOS 26.5
├── Makefile
└── README.md
```

## Technical notes

- **No SIP modifications needed** — works on default macOS security settings
- **No Xcode required** — Metal shaders compile at runtime from source
- **The interpose layer** uses the standard dyld `__DATA,__interpose` section to
  hook OpenGL functions at load time. No runtime patching, no code injection.
- **VRAM unlock** works via dyld interpose of the COM methods that return the
  cap. The `vram-unlock.sh` tool provides a device-level ExtraData override
  as a fallback.
- **The built VBoxSVC** with `MaxGuestVRAM=8192` is in the repo but cannot be
  installed on macOS Sequoia without breaking the app's code signature.
  The runtime interpose achieves the same result without modifying the app.
