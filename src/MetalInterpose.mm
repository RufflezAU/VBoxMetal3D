// MetalInterpose - VirtualBox VRAM unlock for Apple Silicon
// Unified memory means no separate VRAM pool. The 256MB / 1GB caps are
// software artifacts. COM interpose removes the 256MB GUI cap; the SVGA
// device's 1GB hardware limit (VGA_VRAM_MAX) requires building VBoxDD
// from source with a patched VGA_VRAM_MAX in include/VBox/param.h.

#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <pthread.h>

typedef struct { const void* replacement; const void* original; } InterposeEntry;

// CSystemProperties::GetMaxGuestVRAM() — returns the 256MB GUI cap
extern "C" uint32_t __ZNK17CSystemProperties15GetMaxGuestVRAMEv(void);
static uint32_t myGetMaxGuestVRAM(void) { return 8192; }

// CPlatformProperties::GetSupportedVRAMRange — also caps at 256MB
extern "C" int __ZN19CPlatformProperties21GetSupportedVRAMRangeE23KGraphicsControllerTypeiRjS1_(
    void*, uint32_t, int, uint32_t*, uint32_t*, uint32_t*);
static int myGetSupportedVRAMRange(void* self, uint32_t ctl, int accel3d,
                                    uint32_t* min, uint32_t* max, uint32_t* stride) {
    int r = __ZN19CPlatformProperties21GetSupportedVRAMRangeE23KGraphicsControllerTypeiRjS1_(
        self, ctl, accel3d, min, max, stride);
    if (max && *max < 8192) *max = 8192;
    return r;
}

static const InterposeEntry s_interpose[]
    __attribute__((section("__DATA,__interpose"), used)) = {
    { (const void*)myGetMaxGuestVRAM,        (const void*)__ZNK17CSystemProperties15GetMaxGuestVRAMEv },
    { (const void*)myGetSupportedVRAMRange,  (const void*)__ZN19CPlatformProperties21GetSupportedVRAMRangeE23KGraphicsControllerTypeiRjS1_ },
};

__attribute__((constructor))
static void init(void) {
    @autoreleasepool {
        NSString *name = [[NSProcessInfo processInfo] processName];
        if (![name isEqualToString:@"VirtualBoxVM"]
            && ![name isEqualToString:@"VBoxHeadless"]
            && ![name isEqualToString:@"VBoxXPCOMIPCD"]) {
            NSLog(@"VBoxMetal3D: VRAM GUI cap unlocked to 8192MB");
        }
    }
}
