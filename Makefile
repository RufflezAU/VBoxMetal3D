# UTMetal3D Build System
OBJROOT = obj
DESTDIR = $(HOME)/Library/UTMetal3D
SDK = macosx
ARCH = arm64
OSVER = 15.0

CFLAGS = -target $(ARCH)-apple-macos$(OSVER) \
         -fobjc-arc -fobjc-weak \
         -Wall -Wno-deprecated-declarations -O2

LDFLAGS = -dynamiclib \
          -install_name @rpath/UTMetalAccel.dylib \
          -current_version 1.0.0 -compatibility_version 1.0.0 \
          -fobjc-arc \
          -framework Metal -framework Foundation \
          -Wl,-undefined,dynamic_lookup

SOURCES = src/UTMetalAccel.mm
OBJECTS = $(SOURCES:src/%.mm=$(OBJROOT)/%.o)
TARGET  = $(OBJROOT)/UTMetalAccel.dylib

.PHONY: all clean install uninstall patch-qemu

all: $(TARGET)

$(OBJROOT):
	mkdir -p $(OBJROOT)

$(OBJROOT)/%.o: src/%.mm | $(OBJROOT)
	xcrun -sdk $(SDK) clang $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJECTS) | $(OBJROOT)
	xcrun -sdk $(SDK) clang $(CFLAGS) $(LDFLAGS) $(OBJECTS) -o $@
	@echo "✓ UTMetalAccel.dylib built ($(shell stat -f '%z' $@) bytes)"

install: $(TARGET) tools/utm-metal.sh /tmp/insert_dylib
	cp /tmp/insert_dylib $(DESTDIR)/
	mkdir -p $(DESTDIR)
	cp $(TARGET) $(DESTDIR)/
	cp tools/utm-metal.sh $(DESTDIR)/
	chmod +x $(DESTDIR)/utm-metal.sh
	@echo "✓ Installed to $(DESTDIR)"

uninstall:
	rm -rf $(DESTDIR)
	@echo "✓ Uninstalled"

clean:
	rm -rf $(OBJROOT)
