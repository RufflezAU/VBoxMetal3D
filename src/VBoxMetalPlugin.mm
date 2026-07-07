// VBoxMetalPlugin - Entry point plugin for DYLD injection
// Auto-unlocks VRAM for all VMs when loaded into VirtualBox (not VM processes)

#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#import "MetalContext.h"

static BOOL IsManagerProcess(void) {
    NSString* name = [[NSProcessInfo processInfo] processName];
    return [name isEqualToString:@"VirtualBox"]
        || [name isEqualToString:@"VBoxSVC"]
        || [name hasPrefix:@"VBoxManage"];
}

static BOOL IsDangerousProcess(void) {
    // VM processes should NOT run VBoxManage or other host commands
    NSString* name = [[NSProcessInfo processInfo] processName];
    return [name isEqualToString:@"VirtualBoxVM"]
        || [name isEqualToString:@"VBoxHeadless"]
        || [name isEqualToString:@"VBoxXPCOMIPCD"];
}

__attribute__((constructor))
static void VBoxMetalPluginInit(void) {
    @autoreleasepool {
        // Skip dangerous VM processes
        if (IsDangerousProcess()) return;

        VBoxMetalContext* ctx = VBoxMetalGetGlobalContext();
        if (ctx) {
            NSLog(@"VBoxMetal3D: ╔══════════════════════════════════════╗");
            NSLog(@"VBoxMetal3D: ║   VBoxMetal3D GPU Acceleration       ║");
            NSLog(@"VBoxMetal3D: ║   Active in: %@", [[NSProcessInfo processInfo] processName]);
            NSLog(@"VBoxMetal3D: ║   Metal GPU: %@", ctx.device.name);
            NSLog(@"VBoxMetal3D: ║   All OpenGL → Metal via interpose   ║");
            NSLog(@"VBoxMetal3D: ╚══════════════════════════════════════╝");

            // Auto-unlock VRAM to 8GB for all VMs (only in manager processes)
            if (IsManagerProcess()) {
                const char* vbox = "/Applications/VirtualBox.app/Contents/MacOS/VBoxManage";
                char cmd[4096];
                snprintf(cmd, sizeof(cmd),
                    "%s list vms 2>/dev/null | grep -o '\"[^\"]*\"' | tr -d '\"' | "
                    "while read vm; do "
                    "%s setextradata \"$vm\" "
                    "\"VBoxInternal/Devices/vga/0/Config/VRamSize\" 8192 "
                    "2>/dev/null; done", vbox, vbox);
                system(cmd);
                NSLog(@"VBoxMetal3D: ✓ VRAM unlocked to 8GB for all VMs");
            }
        }
    }
}
