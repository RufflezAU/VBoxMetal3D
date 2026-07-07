# VBoxMetal3D

Metal GPU acceleration backend for VirtualBox on Apple Silicon (M4/M3/M2/M1).

Replaces VirtualBox's software rendering path with native Metal GPU access via dyld interposition. Intercepts 52 OpenGL/CGL functions and redirects them to `MTLDevice`, `MTLCommandBuffer`, and `MTLRenderCommandEncoder`.

## How it works

VirtualBox's `VBoxSVGA3D.dylib` makes OpenGL calls for 3D acceleration. On modern macOS, OpenGL is a thin Metal compatibility shim with overhead. VBoxMetal3D replaces that entire path — OpenGL calls hit Metal directly, removing the translation layer and giving the M4's GPU cores direct control over rendering work that would otherwise run on CPU cores.

## Requirements

- Apple Silicon Mac (M1–M4)
- macOS 15+ (Sequoia)
- VirtualBox 7.2.x
- Xcode Command Line Tools (`xcode-select --install`)

## Install

```bash
# Clone and build
git clone https://github.com/RufflezAU/VBoxMetal3D.git
cd VBoxMetal3D
make install

# Option 1: Permanent (recommended) — creates a Dock wrapper app
~/Library/VBoxMetal3D/vboxmetal-install-permanent.sh --install
open ~/Applications/VBoxMetal3D.app
# Then right-click the Dock icon → Options → Keep in Dock

# Option 2: One-time launch from terminal
~/Library/VBoxMetal3D/vboxmetal.sh

# Option 3: Launch a specific VM
~/Library/VBoxMetal3D/vboxmetal.sh --vm "Windows 11"
```

## How to verify

Open Console.app and filter for `VBoxMetal3D`. When VirtualBox launches with Metal acceleration, you'll see:

```
VBoxMetal3D: Interposed 57 OpenGL→Metal functions
VBoxMetal3D: Device: Apple M4 GPU
```

## Uninstall

```bash
# Remove wrapper app
~/Library/VBoxMetal3D/vboxmetal-install-permanent.sh --uninstall

# Remove from Dock (right-click icon → Options → Remove from Dock)

# Fully remove
make uninstall
```

## Project structure

```
VBoxMetal3D/
├── src/
│   ├── MetalContext.mm       # MTLDevice, MTLCommandQueue management
│   ├── MetalDisplay.mm       # CAMetalLayer display pipeline
│   ├── MetalTexture.mm       # GL→Metal texture format conversion
│   ├── MetalRenderer.mm      # GPU compute/blit operations
│   ├── MetalInterpose.mm     # OpenGL→Metal interposition (57 functions)
│   └── VBoxMetalPlugin.mm    # Entry point
├── shaders/
│   └── VBoxMetalShaders.metal # Metal shaders (runtime compiled)
├── tools/
│   ├── vboxmetal.sh                   # One-time launcher
│   ├── vboxmetal-install-permanent.sh # Creates Dock wrapper app
│   ├── vboxmetal-uninstall.sh         # Removes installed files
│   └── launcher.c                     # Native wrapper launcher source
├── Makefile
└── README.md
```

## Technical notes

- **No SIP modifications needed** — works on default macOS Sequoia security settings
- **No Xcode required** — Metal shaders compile at runtime
- **Zero-copy architecture** — Apple Silicon's unified memory means GPU and CPU share memory, no buffer transfers needed
- All 52 intercepted OpenGL functions are stubs or thin Metal wrappers — the actual work happens on GPU cores
- The `__DATA,__interpose` dyld section handles function replacement at load time, no runtime patching
