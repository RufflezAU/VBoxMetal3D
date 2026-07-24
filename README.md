# UTMetal3D — Metal GPU Acceleration for UTM/QEMU on Apple Silicon

Metal GPU acceleration for UTM virtual machines on Apple Silicon (M1–M4).
Intercepts the VirGL → ANGLE → Metal rendering pipeline and provides direct
Metal access, reducing translation overhead for 3D workloads in Windows and
Linux VMs.

## The Problem

When running 3D applications in a UTM Windows/Linux VM on Apple Silicon,
the graphics pipeline is:

```
Guest:  3D API (DirectX/OpenGL) → VirtIO GPU driver → VirGL protocol
Host:   QEMU → virglrenderer → epoxy → ANGLE (EGL/GLESv2) → Metal
```

ANGLE translates OpenGL ES → Metal, adding overhead. This project intercepts
at the epoxy layer to provide direct Metal access.

## What's Included

### UTMetalAccel.dylib
Interpose library that:
- Registers dyld callbacks to detect when virglrenderer loads
- Creates a Metal device and command queue
- Discovers all 277 epoxy GLES/EGL dispatch symbols
- Phase 1: Traces all GL calls (logging + forwarding)
- Phase 2: Replaces hot-path functions with direct Metal implementations

### Epoxy Framework Wrapper
A drop-in replacement for UTM's `epoxy.0.framework` that:
- Reexports all 3426 epoxy symbols to the real epoxy via `LC_REEXPORT_DYLIB`
- Adds tracing/interception via a constructor
- Preserves full backward compatibility

### Mach-O Patching Tools
- `insert_dylib.c` — C tool to inject `LC_LOAD_DYLIB` into fat Mach-O binaries
- Python patcher — Replaces IOSurface LC_LOAD_DYLIB entry with custom dylib path

### QEMU Launcher
Standalone launcher that bypasses UTM entirely for direct QEMU access.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ UTM Process (dlopen's QEMU framework)                   │
│                                                         │
│  QEMU Framework                                         │
│  ├── virglrenderer ──→ epoxy_* dispatch calls           │
│  │                          │                           │
│  │                     ┌────▼─────┐                     │
│  │                     │  Epoxy   │ (our wrapper)        │
│  │                     │ Wrapper  │ ── reexports ──►     │
│  │                     └────┬─────┘   real epoxy.0       │
│  │                          │                           │
│  │                     ┌────▼─────┐                     │
│  │                     │ UTMetal  │ Metal device +       │
│  │                     │ Accel    │ dyld callback        │
│  │                     └──────────┘                     │
│  │                                                      │
│  └── Metal.framework                                    │
└─────────────────────────────────────────────────────────┘
```

### How epoxy dispatch works

Epoxy uses data symbols (function pointers) not code:
- `epoxy.0.framework` exports 3426 `D` (data) symbols
- These are function pointers populated at runtime via `dlsym`
- virglrenderer imports `_epoxy_glCreateProgram` etc. as undefined symbols
- dyld resolves them to epoxy's data section at load time
- Our wrapper reexports all symbols, adding an interception layer

## Build

```bash
make install
# Installs to ~/Library/UTMetal3D/
#   - UTMetalAccel.dylib
#   - insert_dylib
#   - utm-metal.sh
```

## Deployment Requirements

macOS Sequoia (26.x) blocks all code injection paths for unsigned code:

| Method | Status | Blocker |
|--------|--------|---------|
| `DYLD_INSERT_LIBRARIES` | ❌ | AMFI blocks system-wide |
| Binary patching (LC_LOAD_DYLIB) | ❌ | Breaks code signature |
| Framework replacement | ❌ | `virtualization` entitlement needed |
| Ad-hoc signing + entitlements | ❌ | macOS ignores non-Apple entitlements |
| ldid entitlements | ❌ | macOS ignores non-Apple signatures |
| lldb attach + dlopen | ❌ | Hardened runtime blocks attach |

### To deploy, you need ONE of:

1. **Apple Developer ID** ($99/yr) — sign with real certificate, entitlements
   work, framework replacement deploys cleanly

2. **Disable SIP** — `csrutil disable` in Recovery Mode, then all injection
   methods work

3. **Future macOS** — if Apple relaxes restrictions, code deploys as-is

## VM Configuration

The target VM should use:
- **Display**: `virtio-ramfb-gl` (VirtIO GPU with GL acceleration)
- **Hypervisor**: enabled (HVF for hardware CPU acceleration)
- **Guest drivers**: VirtIO GPU driver installed (viogpudo.sys)
- **DirectX**: Feature levels up to 12_1 reported by VirtIO DOD driver

## Baseline Performance

Tested with Warcraft III on Windows 11 ARM:
- **Without UTMetal3D**: 49 FPS (software rendering via VirGL→ANGLE→Metal)
- **With UTMetal3D** (Phase 2): Targeting 60+ FPS by bypassing ANGLE overhead

## Findings

### UTM's GPU Stack
- UTM bundles Google ANGLE (EGL.framework + GLESv2.framework) → Metal
- virglrenderer uses epoxy dispatch (3426 data symbols)
- QEMU has rutabaga/venus support compiled in but not active
- VirtIO GPU driver reports D3D feature levels 12_1 through 9_1
- Display-Only Driver (DOD) — no hardware 3D acceleration in guest

### macOS Security Analysis
- `codesign --deep` with ad-hoc signing resolves team-ID mismatch
- `disable-library-validation` entitlement not honored for ad-hoc signatures
- `virtualization` entitlement required for HVF (hardware accel)
- TCG (software emulation) avoids entitlement but VM won't start
- ldid can embed entitlements but macOS ignores non-Apple signatures

## Files

```
UTMetal3D/
├── src/
│   └── UTMetalAccel.mm          # Metal interpose library
├── tools/
│   ├── insert_dylib.c           # Mach-O LC_LOAD_DYLIB injector
│   ├── utm-metal.sh             # Management script
│   ├── utm-metal-launcher.sh    # VM launcher
│   ├── utm-wrapper.c            # C wrapper for UTM binary
│   └── qemu-launcher.c          # Direct QEMU launcher
├── scripts/
│   └── gen_interpose.py         # Code generator for interpose entries
├── Makefile
└── README.md
```

## License

MIT

## Acknowledgments

- [VBoxMetal3D](https://github.com/RufflezAU/VBoxMetal3D) — original VirtualBox
  Metal interpose that inspired this project
- [UTM](https://mac.getutm.app) — QEMU-based virtualization for macOS
- [Google ANGLE](https://github.com/google/angle) — OpenGL ES → Metal translation
- [epoxy](https://github.com/anholt/libepoxy) — GL function pointer dispatch