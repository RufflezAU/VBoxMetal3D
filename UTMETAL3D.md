# UTMetal3D — Metal GPU for UTM/QEMU

A companion project that applies the same Metal interpose technique from VBoxMetal3D
to UTM/QEMU virtual machines on Apple Silicon.

## Repository

**https://github.com/RufflezAU/UTMetal3D**

Also available as a branch in this repo: `utm-metal3d`

## What it does

- Intercepts the VirGL → ANGLE → Metal rendering pipeline in UTM
- Provides direct Metal access bypassing ANGLE's OpenGL ES translation
- Targets Windows 11 ARM and Linux VMs with VirtIO GPU (virtio-ramfb-gl)

## Relationship to VBoxMetal3D

| | VBoxMetal3D | UTMetal3D |
|---|---|---|
| **Target** | VirtualBox | UTM (QEMU) |
| **Interception** | OpenGL/CGL → Metal | epoxy dispatch → Metal |
| **Guest 3D** | VMSVGA (Guest Additions) | VirGL (VirtIO GPU) |
| **Host rendering** | CPU OpenGL → Metal | ANGLE GLES → Metal |
| **Injection** | dyld interpose | epoxy reexport wrapper |

Both projects solve the same problem: Apple deprecated OpenGL on macOS, forcing
VM display pipelines through slow software rendering. By intercepting at the
host level and routing directly to Metal, both projects provide GPU acceleration.
