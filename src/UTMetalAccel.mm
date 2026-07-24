// UTMetal3D — Metal GPU acceleration for UTM/QEMU on Apple Silicon
// Phase 1: Tracing — detects QEMU framework load via dyld callback,
// then discovers and logs all available epoxy GLES/EGL symbols.
// (Does NOT interpose dlopen, avoiding recursion issues on dyld4)

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

static id<MTLDevice> g_metalDevice = nil;
static BOOL g_epoxyChecked = NO;

// ---------------------------------------------------------------------------
// Epoxy symbol discovery — runs after QEMU/epoxy frameworks are loaded
// ---------------------------------------------------------------------------
static void discoverEpoxySymbols(void) {
    if (g_epoxyChecked) return;
    g_epoxyChecked = YES;

    NSLog(@"UTMetal3D: Scanning for epoxy symbols...");

    const char *targets[] = {
        "epoxy_eglGetDisplay", "epoxy_eglInitialize", "epoxy_eglChooseConfig",
        "epoxy_eglCreateContext", "epoxy_eglMakeCurrent", "epoxy_eglSwapBuffers",
        "epoxy_eglCreateWindowSurface", "epoxy_eglDestroySurface",
        "epoxy_eglDestroyContext", "epoxy_eglTerminate", "epoxy_eglBindAPI",
        "epoxy_eglGetError", "epoxy_eglGetCurrentContext", "epoxy_eglQueryString",
        "epoxy_eglGetProcAddress",
        "epoxy_eglCreateSyncKHR", "epoxy_eglClientWaitSyncKHR",
        "epoxy_glCreateProgram", "epoxy_glCreateShader",
        "epoxy_glShaderSource", "epoxy_glCompileShader", "epoxy_glAttachShader",
        "epoxy_glLinkProgram", "epoxy_glUseProgram",
        "epoxy_glViewport", "epoxy_glClear", "epoxy_glClearColor",
        "epoxy_glDrawArrays", "epoxy_glDrawElements",
        "epoxy_glGenTextures", "epoxy_glBindTexture",
        "epoxy_glTexImage2D", "epoxy_glTexSubImage2D",
        "epoxy_glGenFramebuffers", "epoxy_glBindFramebuffer",
        "epoxy_glFramebufferTexture2D",
        "epoxy_glGenBuffers", "epoxy_glBindBuffer", "epoxy_glBufferData",
        "epoxy_glGetIntegerv", "epoxy_glGetString", "epoxy_glGetError",
        "epoxy_glEnable", "epoxy_glDisable",
        "epoxy_glBlendFunc", "epoxy_glDepthFunc", "epoxy_glDepthMask",
        "epoxy_glCullFace", "epoxy_glFrontFace", "epoxy_glColorMask",
        "epoxy_glFlush", "epoxy_glFinish", "epoxy_glFlush",
        "epoxy_glGenVertexArrays", "epoxy_glBindVertexArray",
        "epoxy_glGetAttribLocation", "epoxy_glGetUniformLocation",
        "epoxy_glUniform1i", "epoxy_glUniformMatrix4fv",
        "epoxy_glGetShaderiv", "epoxy_glGetShaderInfoLog",
        "epoxy_glGetProgramiv", "epoxy_glGetProgramInfoLog",
        NULL
    };

    int found = 0;
    for (int i = 0; targets[i]; i++) {
        void *sym = dlsym(RTLD_DEFAULT, targets[i]);
        if (sym) {
            NSLog(@"UTMetal3D:   ✓ %s  (%p)", targets[i], sym);
            found++;
        }
    }
    int total = (int)(sizeof(targets) / sizeof(targets[0])) - 1;
    NSLog(@"UTMetal3D: Found %d/%d epoxy symbols — VirGL GLES backend is available", found, total);

    // Also check EGL.framework directly
    void *egl = dlsym(RTLD_DEFAULT, "eglInitialize");
    void *gles = dlsym(RTLD_DEFAULT, "glClearColor");
    if (egl) NSLog(@"UTMetal3D:   ANGLE EGL loaded at %p", egl);
    if (gles) NSLog(@"UTMetal3D:   ANGLE GLES loaded at %p", gles);
}

// ---------------------------------------------------------------------------
// Dyld callback — fires when ANY new image is loaded into the process
// We use this to detect when the QEMU (and thus epoxy/ANGLE) framework loads
// ---------------------------------------------------------------------------
static void imageAddedCallback(const struct mach_header *mh, intptr_t vmaddr_slide) {
    // _dyld_register_func_for_add_image fires during initial load AND for new images.
    // We need to find our target among all loaded images.
    uint32_t count = _dyld_image_count();
    BOOL qemuFound = NO;
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "qemu-aarch64-softmmu")) {
            qemuFound = YES;
            break;
        }
    }
    if (qemuFound) {
        dispatch_async(dispatch_get_main_queue(), ^{
            discoverEpoxySymbols();
        });
    }
}

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------
__attribute__((constructor))
static void UTMetal3DInit(void) {
    @autoreleasepool {
        NSString *pname = [[NSProcessInfo processInfo] processName];
        NSLog(@"UTMetal3D: v1.0.0 loaded into %@ (pid %d)", pname, getpid());

        g_metalDevice = MTLCreateSystemDefaultDevice();
        if (g_metalDevice) {
            NSLog(@"UTMetal3D: Metal device: %@", [g_metalDevice name]);
        }

        // Register dyld callback for image loading
        _dyld_register_func_for_add_image(imageAddedCallback);

        // Also check if QEMU is already loaded (unlikely at this point, but safe)
        void *qemuHandle = dlopen(
            "/Applications/UTM.app/Contents/Frameworks/qemu-aarch64-softmmu.framework/qemu-aarch64-softmmu",
            RTLD_NOLOAD | RTLD_LOCAL);
        if (!qemuHandle) {
            NSString *ourQemu = [NSHomeDirectory()
                stringByAppendingPathComponent:@"Applications/UTMetal3D.app/Contents/Frameworks/"
                "qemu-aarch64-softmmu.framework/qemu-aarch64-softmmu"];
            qemuHandle = dlopen([ourQemu UTF8String], RTLD_NOLOAD | RTLD_LOCAL);
        }
        if (qemuHandle) {
            NSLog(@"UTMetal3D: QEMU already loaded — scanning epoxy symbols");
            discoverEpoxySymbols();
        } else {
            NSLog(@"UTMetal3D: Waiting for QEMU framework to load via dyld callback");
        }
    }
}
