// VBoxMetalPlugin - Entry point plugin for DYLD injection
// This simply logs that Metal acceleration is active

#import <Foundation/Foundation.h>
#import "MetalContext.h"

__attribute__((constructor))
static void VBoxMetalPluginInit(void) {
    @autoreleasepool {
        VBoxMetalContext* ctx = VBoxMetalGetGlobalContext();
        if (ctx) {
            NSLog(@"VBoxMetal3D: ╔══════════════════════════════════════╗");
            NSLog(@"VBoxMetal3D: ║   VBoxMetal3D GPU Acceleration       ║");
            NSLog(@"VBoxMetal3D: ║   Active in: %@", [[NSProcessInfo processInfo] processName]);
            NSLog(@"VBoxMetal3D: ║   Metal GPU: %@", ctx.device.name);
            NSLog(@"VBoxMetal3D: ║   All OpenGL → Metal via interpose   ║");
            NSLog(@"VBoxMetal3D: ╚══════════════════════════════════════╝");
        }
    }
}
