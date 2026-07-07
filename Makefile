# VBoxMetal3D Build System

OBJROOT = obj
DESTDIR = $(HOME)/Library/VBoxMetal3D
SDK = macosx
ARCH = arm64
OSVER = 15.0

CFLAGS = -target $(ARCH)-apple-macos$(OSVER) \
         -fobjc-arc -fobjc-weak -I. -Isrc \
         -Wall -Wno-deprecated-declarations -O2

LDFLAGS = -dynamiclib \
          -install_name @rpath/VBoxMetalAccel.dylib \
          -current_version 1.0.0 -compatibility_version 1.0.0 \
          -fobjc-arc \
          -framework Metal -framework MetalPerformanceShaders \
          -framework Cocoa -framework CoreGraphics \
          -framework CoreVideo -framework QuartzCore -framework IOKit \
          -Wl,-undefined,dynamic_lookup

SOURCES = \
    src/MetalInterpose.mm \
    src/VBoxMetalPlugin.mm

OBJECTS = $(SOURCES:src/%.mm=$(OBJROOT)/%.o)
TARGET = $(OBJROOT)/VBoxMetalAccel.dylib

.PHONY: all clean install uninstall

all: $(TARGET)

$(OBJROOT):
	mkdir -p $(OBJROOT)

$(OBJROOT)/%.o: src/%.mm | $(OBJROOT)
	xcrun -sdk $(SDK) clang $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJECTS) | $(OBJROOT)
	xcrun -sdk $(SDK) clang $(CFLAGS) $(LDFLAGS) $(OBJECTS) -o $@
	@echo "✓ VBoxMetalAccel.dylib built ($$(stat -f '%z' $@) bytes)"

install: $(TARGET) tools/vboxmetal.sh
	mkdir -p $(DESTDIR)
	cp $(TARGET) $(DESTDIR)/
	cp tools/vboxmetal.sh $(DESTDIR)/
	chmod +x $(DESTDIR)/vboxmetal.sh
	@echo "Installed to $(DESTDIR)"

uninstall:
	rm -rf $(DESTDIR)

clean:
	rm -rf $(OBJROOT)
