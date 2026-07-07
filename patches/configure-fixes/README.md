# Build Configuration Fixes for macOS 26.5

These files fix the VirtualBox 7.2.12 configure and build system
for macOS 26.5 (Darwin 25, Apple Silicon M4).

## Files

- `configure-darwin25.patch` — adds Darwin 25 support to configure script
- `MACOSX265.kmk` — kBuild SDK definition for macOS 26.5 SDK
- `MACOSX265INCS.kmk` — kBuild SDK includes definition

## Prerequisites

- Full Xcode (not just Command Line Tools)
- Xcode CLT: `xcode-select --install`
- Homebrew packages: `brew install yasm qt@6`
- Create symlinks for llvm tools:
  ```bash
  sudo ln -s /usr/bin/ar /usr/local/bin/llvm-ar
  sudo ln -s /usr/bin/nm /usr/local/bin/llvm-nm
  ```

## Build

```bash
curl -L https://download.virtualbox.org/virtualbox/7.2.12/VirtualBox-7.2.12.tar.bz2 | tar xj
cd VirtualBox-7.2.12

# Apply all patches:
# 1. VRAM unlock patches
patch -p1 < path/to/patches/0001-vram-unlock-8192mb.patch
# 2. Configure fix
patch -p1 < path/to/patches/configure-fixes/configure-darwin25.patch
# 3. Copy SDK definitions
cp path/to/patches/configure-fixes/MACOSX265.kmk kBuild/sdks/
cp path/to/patches/configure-fixes/MACOSX265INCS.kmk kBuild/sdks/

./configure --disable-hardening --disable-qt
source env.sh
kmk  # takes 1-2 hours
```
