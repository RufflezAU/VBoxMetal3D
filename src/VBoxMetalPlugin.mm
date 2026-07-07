// VBoxMetalPlugin - VRAM unlock for VirtualBox on Apple Silicon

#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static BOOL IsManagerProcess(void) {
    NSString* name = [[NSProcessInfo processInfo] processName];
    return [name isEqualToString:@"VirtualBox"]
        || [name isEqualToString:@"VBoxSVC"]
        || [name hasPrefix:@"VBoxManage"];
}

static BOOL IsDangerousProcess(void) {
    NSString* name = [[NSProcessInfo processInfo] processName];
    return [name isEqualToString:@"VirtualBoxVM"]
        || [name isEqualToString:@"VBoxHeadless"]
        || [name isEqualToString:@"VBoxXPCOMIPCD"];
}

__attribute__((constructor))
static void VBoxMetalPluginInit(void) {
    @autoreleasepool {
        if (IsDangerousProcess()) return;

        NSLog(@"VBoxMetal3D: Active in %@", [[NSProcessInfo processInfo] processName]);

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
            NSLog(@"VBoxMetal3D: VRAM unlocked to 8GB");
        }
    }
}
