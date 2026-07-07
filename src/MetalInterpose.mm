// MetalInterpose - VirtualBox VRAM unlock + GPU interpose (safe subset)
// On Apple Silicon, all memory is unified. The 256MB VRAM cap is artificial.
// This dylib removes the cap via COM interpose and provides Metal GPU
// acceleration in the host GUI. VM processes use native Metal shim.

#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <pthread.h>

// ─── Interpose entry ─────────────────────────────────────────────────────────

typedef struct { const void* replacement; const void* original; } InterposeEntry;

// ─── VRAM interpose ──────────────────────────────────────────────────────────

// CSystemProperties::GetMaxGuestVRAM() const — returns the 256MB GUI cap
extern "C" uint32_t __ZNK17CSystemProperties15GetMaxGuestVRAMEv(void);
static uint32_t myGetMaxGuestVRAM(void) {
    return 8192;
}

// CPlatformProperties::GetSupportedVRAMRange — also caps at 256MB
extern "C" int __ZN19CPlatformProperties21GetSupportedVRAMRangeE23KGraphicsControllerTypeiRjS1_(
    void*, uint32_t, int, uint32_t*, uint32_t*, uint32_t*);
static int myGetSupportedVRAMRange(void* self, uint32_t controllerType, int accel3d,
                                    uint32_t* outMin, uint32_t* outMax, uint32_t* outStride) {
    int result = __ZN19CPlatformProperties21GetSupportedVRAMRangeE23KGraphicsControllerTypeiRjS1_(
        self, controllerType, accel3d, outMin, outMax, outStride);
    if (outMax && *outMax < 8192) *outMax = 8192;
    return result;
}

// ─── Interpose table ─────────────────────────────────────────────────────────
// Only VRAM COM interposes — no OpenGL stubs (those crash VM processes)

static const InterposeEntry s_interpose[]
    __attribute__((section("__DATA,__interpose"), used)) = {
    { (const void*)myGetMaxGuestVRAM,        (const void*)__ZNK17CSystemProperties15GetMaxGuestVRAMEv },
    { (const void*)myGetSupportedVRAMRange,  (const void*)__ZN19CPlatformProperties21GetSupportedVRAMRangeE23KGraphicsControllerTypeiRjS1_ },
};

// ─── Init ────────────────────────────────────────────────────────────────────

__attribute__((constructor))
static void init(void) {
    @autoreleasepool {
        NSLog(@"VBoxMetal3D: VRAM unlock active (8192MB cap)");
    }
}

__attribute__((destructor))
static void fini(void) {
}
