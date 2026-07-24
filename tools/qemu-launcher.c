// QEMU Launcher — loads patched QEMU framework and boots a VM
// Bypasses UTM completely for direct GPU acceleration
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>

int main(int argc, char *argv[]) {
    // Set QEMU firmware path
    setenv("QEMU_FIRMWARE_PATH",
        "/Users/nicholasrussell/Applications/UTMetal3D.app/Contents/Resources/qemu",
        1);

    // Load the patched QEMU framework (LC_LOAD_DYLIB triggers our interpose)
    void *handle = dlopen(
        "/Users/nicholasrussell/Applications/UTMetal3D.app/Contents/Frameworks/qemu-aarch64-softmmu.framework/qemu-aarch64-softmmu",
        RTLD_LAZY | RTLD_LOCAL);
    
    if (!handle) {
        fprintf(stderr, "Failed to load QEMU: %s\n", dlerror());
        // Fall back to the original UTM bundle path
        handle = dlopen(
            "/Applications/UTM.app/Contents/Frameworks/qemu-aarch64-softmmu.framework/qemu-aarch64-softmmu",
            RTLD_LAZY | RTLD_LOCAL);
    }
    
    if (!handle) {
        fprintf(stderr, "Failed to load QEMU from any path: %s\n", dlerror());
        return 1;
    }

    // Find and call QEMU's main entry point
    typedef int (*qemu_main_t)(int, char **, char **);
    qemu_main_t qemu_main = (qemu_main_t)dlsym(handle, "qemu_main");
    
    if (!qemu_main) {
        // Try other names
        qemu_main = (qemu_main_t)dlsym(handle, "main");
    }
    
    if (!qemu_main) {
        fprintf(stderr, "Cannot find QEMU entry point\n");
        return 1;
    }

    printf("QEMU loaded at %p, entry at %p\n", handle, qemu_main);
    
    // Build QEMU args from command line
    // First arg should be the program name
    char *qemu_argv[argc + 1];
    qemu_argv[0] = "qemu-system-aarch64";
    for (int i = 1; i < argc; i++)
        qemu_argv[i] = argv[i];
    qemu_argv[argc] = NULL;

    // Call QEMU main
    return qemu_main(argc, qemu_argv, *(_NSGetEnviron()));
}
