// VBoxMetal3D Launcher - sets Metal env and launches VirtualBox
// Compile: clang -target arm64-apple-macos15.0 -o VBoxMetal3D launcher.c
// Then create ~/Applications/VBoxMetal3D.app wrapping this binary

#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>

#define DYLIB_PATH "/Users/nicholasrussell/Library/VBoxMetal3D/VBoxMetalAccel.dylib"
#define VBOX_EXEC "/Applications/VirtualBox.app/Contents/MacOS/VirtualBox"

int main(int argc, char *argv[], char *envp[]) {
    setenv("DYLD_INSERT_LIBRARIES", DYLIB_PATH, 1);

    char *args[argc + 1];
    args[0] = VBOX_EXEC;
    for (int i = 1; i < argc; i++)
        args[i] = argv[i];
    args[argc] = NULL;

    execv(VBOX_EXEC, args);

    // If execv fails, fall back to open command
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "open -a '/Applications/VirtualBox.app'");
    for (int i = 1; i < argc; i++) {
        strcat(cmd, " '");
        strcat(cmd, argv[i]);
        strcat(cmd, "'");
    }
    return system(cmd);
}
