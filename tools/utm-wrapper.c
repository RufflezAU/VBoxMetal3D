// UTMetal3D wrapper — sets DYLD_INSERT_LIBRARIES and execs real UTM
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>

#define DYLIB_PATH "/Users/nicholasrussell/Library/UTMetal3D/UTMetalAccel.dylib"
#define UTM_REAL  "/Users/nicholasrussell/Applications/UTMetal3D.app/Contents/MacOS/UTM.real"

int main(int argc, char *argv[], char *envp[]) {
    // Set the env var
    setenv("DYLD_INSERT_LIBRARIES", DYLIB_PATH, 1);

    // Build args: first arg is the real UTM path
    char *args[argc + 1];
    args[0] = UTM_REAL;
    for (int i = 1; i < argc; i++)
        args[i] = argv[i];
    args[argc] = NULL;

    execv(UTM_REAL, args);

    // If execv fails, try via open
    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
        "DYLD_INSERT_LIBRARIES=%s open '%s'",
        DYLIB_PATH,
        "/Users/nicholasrussell/Applications/UTMetal3D.app");
    return system(cmd);
}
