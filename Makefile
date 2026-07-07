# VBoxMetal3D Build System
# Targets: arm64-apple-macos15.0 (Apple Silicon M4)

OBJROOT = obj
DESTDIR = $(HOME)/Library/VBoxMetal3D

SDK = macosx
ARCH = arm64
OSVER = 15.0

CFLAGS = -target $(ARCH)-apple-macos$(OSVER) \
         -fobjc-arc \
         -fobjc-weak \
         -I. -Isrc \
         -Wall -Wno-deprecated-declarations \
         -O2

LDFLAGS = -dynamiclib \
          -install_name @rpath/VBoxMetalAccel.dylib \
          -current_version 1.0.0 \
          -compatibility_version 1.0.0 \
          -fobjc-arc \
          -framework Metal \
          -framework MetalPerformanceShaders \
          -framework Cocoa \
          -framework CoreGraphics \
          -framework CoreVideo \
          -framework QuartzCore \
          -framework IOKit \
          -Wl,-undefined,dynamic_lookup

SOURCES = \
    src/MetalContext.mm \
    src/MetalDisplay.mm \
    src/MetalTexture.mm \
    src/MetalRenderer.mm \
    src/MetalInterpose.mm \
    src/VBoxMetalPlugin.mm

OBJECTS = $(SOURCES:src/%.mm=$(OBJROOT)/%.o)
TARGET = $(OBJROOT)/VBoxMetalAccel.dylib

.PHONY: all clean install uninstall test run

all: $(TARGET)

$(OBJROOT):
	mkdir -p $(OBJROOT)

$(OBJROOT)/%.o: src/%.mm | $(OBJROOT)
	xcrun -sdk $(SDK) clang $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJECTS) | $(OBJROOT)
	xcrun -sdk $(SDK) clang $(CFLAGS) $(LDFLAGS) $(OBJECTS) -o $@
	@echo ""
	@echo "✓ VBoxMetalAccel.dylib built successfully"
	@echo "  Size: $$(stat -f '%z' $@) bytes"

install: $(TARGET) tools/vboxmetal.sh tools/vboxmetal-uninstall.sh tools/vboxmetal-install-permanent.sh
	mkdir -p $(DESTDIR)
	cp $(TARGET) $(DESTDIR)/
	cp shaders/VBoxMetalShaders.metal $(DESTDIR)/
	cp tools/vboxmetal.sh $(DESTDIR)/
	cp tools/vboxmetal-uninstall.sh $(DESTDIR)/
	cp tools/vboxmetal-install-permanent.sh $(DESTDIR)/
	chmod +x $(DESTDIR)/vboxmetal.sh $(DESTDIR)/vboxmetal-uninstall.sh $(DESTDIR)/vboxmetal-install-permanent.sh
	@echo ""
	@echo "═══ VBoxMetal3D Installed ═══"
	@echo "  Location: $(DESTDIR)"
	@echo ""
	@echo "  Launch VirtualBox with Metal acceleration:"
	@echo "    $$ $(DESTDIR)/vboxmetal.sh"
	@echo ""
	@echo "  Or use any VM directly:"
	@echo "    $$ $(DESTDIR)/vboxmetal.sh --vm \"Your VM Name\""
	@echo ""
	@echo "  Remove:"
	@echo "    $$ make uninstall"

uninstall:
	rm -rf $(DESTDIR)
	@echo "VBoxMetal3D uninstalled"

clean:
	rm -rf $(OBJROOT)

run: $(TARGET) $(SHADER_LIB)
	DYLD_INSERT_LIBRARIES=$(TARGET) /Applications/VirtualBox.app/Contents/MacOS/VirtualBox &
