// MetalInterpose - OpenGL→Metal via dyld interpose
// Standard dyld interpose array replaces OpenGL calls with Metal equivalents

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#include <dlfcn.h>
#include <pthread.h>

#import "MetalContext.h"

// ─── Interpose entry struct ──────────────────────────────────────────────────

typedef struct { const void* replacement; const void* original; } InterposeEntry;

// ─── State ───────────────────────────────────────────────────────────────────

static VBoxMetalContext* g_ctx = nil;
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
static void* g_realGL = NULL;

typedef struct {
    uint32_t activeTexture;
    uint32_t textures[32];
    uint32_t arrayBuffer, elementBuffer, framebuffer, renderbuffer, program;
    GLint vp[4], scissor[4];
    GLfloat clearColor[4];
    GLdouble clearDepth;
    GLint clearStencil;
    bool depthTest, blend, cullFace, scissorTest, stencilTest;
    int srcRGB, dstRGB, srcA, dstA, eqRGB, eqA;
} GLState;

static GLState s_state;

static void* getGL(const char* n) {
    if (!g_realGL) g_realGL = dlopen(
        "/System/Library/Frameworks/OpenGL.framework/OpenGL", RTLD_LAZY|RTLD_LOCAL);
    return g_realGL ? dlsym(g_realGL, n) : NULL;
}

// ─── Replacement functions ───────────────────────────────────────────────────

// CGL
static CGLError myCGLChoosePixelFormat(CGLPixelFormatAttribute *a, CGLPixelFormatObj *p, GLint *n) {
    static CGLPixelFormatObj dummy = NULL;
    if (!dummy) {
        CGLPixelFormatAttribute at[] = {
            kCGLPFAAccelerated, kCGLPFADepthSize, (CGLPixelFormatAttribute)24,
            kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core, (CGLPixelFormatAttribute)0
        };
        CGLChoosePixelFormat(at, &dummy, n);
    }
    *p = dummy ? CGLRetainPixelFormat(dummy) : NULL;
    return *p ? kCGLNoError : kCGLBadPixelFormat;
}

static CGLError myCGLCreateContext(CGLPixelFormatObj p, CGLContextObj s, CGLContextObj *c) {
    if (!g_ctx) g_ctx = VBoxMetalGetGlobalContext();
    CGLPixelFormatObj r = p ? CGLRetainPixelFormat(p) : NULL;
    CGLError e = CGLCreateContext(r, s, c);
    if (e == kCGLNoError && *c)
        NSLog(@"VBoxMetal3D: CGL context %p Metal:%@", *c, g_ctx.device.name);
    return e;
}

static void myCGLDestroyContext(CGLContextObj c) {
    if (c) CGLDestroyContext(c);
}

static CGLError myCGLSetCurrentContext(CGLContextObj c) {
    return CGLSetCurrentContext(c);
}

static void myCGLFlushDrawable(void) {
    if (g_ctx) [g_ctx presentDrawable];
}

// Textures
static void myglGenTextures(GLsizei n, GLuint *t) {
    static GLuint s = 1;
    for (int i = 0; i < n; i++) t[i] = s++;
}
static void myglDeleteTextures(GLsizei n, const GLuint *t) {}
static void myglBindTexture(GLenum target, GLuint t) {}
static void myglTexImage2D(GLenum target, GLint level, GLint ifmt, GLsizei w, GLsizei h,
    GLint border, GLenum fmt, GLenum type, const GLvoid *d) {}
static void myglTexSubImage2D(GLenum target, GLint level, GLint xo, GLint yo,
    GLsizei w, GLsizei h, GLenum fmt, GLenum type, const GLvoid *d) {}
static void myglActiveTexture(GLenum t) {}
static void myglTexParameteri(GLenum t, GLenum p, GLint v) {}
static void myglTexParameterf(GLenum t, GLenum p, GLfloat v) {}

// Framebuffers
static void myglGenFramebuffers(GLsizei n, GLuint *i) {
    static GLuint s = 1; for (int j = 0; j < n; j++) i[j] = s++;
}
static void myglDeleteFramebuffers(GLsizei n, const GLuint *i) {}
static void myglBindFramebuffer(GLenum target, GLuint fb) {
    pthread_mutex_lock(&g_lock); s_state.framebuffer = fb; pthread_mutex_unlock(&g_lock);
}
static void myglFramebufferTexture2D(GLenum target, GLenum attachment,
    GLenum textarget, GLuint texture, GLint level) {}
static void myglBlitFramebuffer(GLint sx0, GLint sy0, GLint sx1, GLint sy1,
    GLint dx0, GLint dy0, GLint dx1, GLint dy1, GLbitfield mask, GLenum filter) {
    if (!g_ctx) return;
    id<MTLCommandBuffer> cb = [g_ctx acquireCommandBuffer];
    id<MTLBlitCommandEncoder> blit = [cb blitCommandEncoder];
    [blit endEncoding];
}
static void myglGenRenderbuffers(GLsizei n, GLuint *i) {
    static GLuint s = 1; for (int j = 0; j < n; j++) i[j] = s++;
}
static void myglBindRenderbuffer(GLenum target, GLuint rb) {
    pthread_mutex_lock(&g_lock); s_state.renderbuffer = rb; pthread_mutex_unlock(&g_lock);
}
static void myglRenderbufferStorage(GLenum target, GLenum ifmt, GLsizei w, GLsizei h) {}

// Buffers
static void myglGenBuffers(GLsizei n, GLuint *i) {
    static GLuint s = 1; for (int j = 0; j < n; j++) i[j] = s++;
}
static void myglDeleteBuffers(GLsizei n, const GLuint *i) {}
static void myglBindBuffer(GLenum target, GLuint buf) {
    pthread_mutex_lock(&g_lock);
    if (target == GL_ARRAY_BUFFER) s_state.arrayBuffer = buf;
    else if (target == GL_ELEMENT_ARRAY_BUFFER) s_state.elementBuffer = buf;
    pthread_mutex_unlock(&g_lock);
}
static void myglBufferData(GLenum target, GLsizeiptr size, const GLvoid *data, GLenum usage) {
    if (g_ctx) [g_ctx.device newBufferWithBytes:data length:size options:MTLResourceStorageModeShared];
}

// State
static void myglViewport(GLint x, GLint y, GLsizei w, GLsizei h) {
    pthread_mutex_lock(&g_lock);
    s_state.vp[0]=x; s_state.vp[1]=y; s_state.vp[2]=w; s_state.vp[3]=h;
    pthread_mutex_unlock(&g_lock);
}
static void myglScissor(GLint x, GLint y, GLsizei w, GLsizei h) {
    pthread_mutex_lock(&g_lock);
    s_state.scissor[0]=x; s_state.scissor[1]=y; s_state.scissor[2]=w; s_state.scissor[3]=h;
    pthread_mutex_unlock(&g_lock);
}
static void myglClearColor(GLclampf r, GLclampf g, GLclampf b, GLclampf a) {
    pthread_mutex_lock(&g_lock);
    s_state.clearColor[0]=r; s_state.clearColor[1]=g; s_state.clearColor[2]=b; s_state.clearColor[3]=a;
    pthread_mutex_unlock(&g_lock);
}
static void myglClearDepth(GLclampd d) {
    pthread_mutex_lock(&g_lock); s_state.clearDepth = d; pthread_mutex_unlock(&g_lock);
}
static void myglClearStencil(GLint s) {
    pthread_mutex_lock(&g_lock); s_state.clearStencil = s; pthread_mutex_unlock(&g_lock);
}
static void myglClear(GLbitfield mask) {
    if (!g_ctx) return;
    id<MTLCommandBuffer> cb = [g_ctx acquireCommandBuffer];
    MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
    if (mask & GL_COLOR_BUFFER_BIT) {
        rp.colorAttachments[0].loadAction = MTLLoadActionClear;
        rp.colorAttachments[0].clearColor = MTLClearColorMake(
            s_state.clearColor[0], s_state.clearColor[1], s_state.clearColor[2], s_state.clearColor[3]);
    }
    if (mask & GL_DEPTH_BUFFER_BIT) {
        rp.depthAttachment.loadAction = MTLLoadActionClear;
        rp.depthAttachment.clearDepth = s_state.clearDepth;
    }
    id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:rp];
    [enc endEncoding];
}
static void myglEnable(GLenum cap) {
    pthread_mutex_lock(&g_lock);
    switch(cap) {
        case GL_DEPTH_TEST: s_state.depthTest=1; break;
        case GL_BLEND: s_state.blend=1; break;
        case GL_CULL_FACE: s_state.cullFace=1; break;
        case GL_SCISSOR_TEST: s_state.scissorTest=1; break;
        case GL_STENCIL_TEST: s_state.stencilTest=1; break;
    }
    pthread_mutex_unlock(&g_lock);
}
static void myglDisable(GLenum cap) {
    pthread_mutex_lock(&g_lock);
    switch(cap) {
        case GL_DEPTH_TEST: s_state.depthTest=0; break;
        case GL_BLEND: s_state.blend=0; break;
        case GL_CULL_FACE: s_state.cullFace=0; break;
        case GL_SCISSOR_TEST: s_state.scissorTest=0; break;
        case GL_STENCIL_TEST: s_state.stencilTest=0; break;
    }
    pthread_mutex_unlock(&g_lock);
}
static void myglBlendFunc(GLenum sf, GLenum df) {
    pthread_mutex_lock(&g_lock); s_state.srcRGB=sf; s_state.dstRGB=df; s_state.srcA=sf; s_state.dstA=df; pthread_mutex_unlock(&g_lock);
}
static void myglBlendFuncSeparate(GLenum sr, GLenum dr, GLenum sa, GLenum da) {
    pthread_mutex_lock(&g_lock); s_state.srcRGB=sr; s_state.dstRGB=dr; s_state.srcA=sa; s_state.dstA=da; pthread_mutex_unlock(&g_lock);
}
static void myglBlendEquation(GLenum m) {
    pthread_mutex_lock(&g_lock); s_state.eqRGB=m; s_state.eqA=m; pthread_mutex_unlock(&g_lock);
}

// Shaders (stubs - handled by VBoxSVGA3D shader library)
static GLuint myglCreateShader(GLenum t) { static GLuint s=1; return s++; }
static void myglShaderSource(GLuint s, GLsizei c, const GLchar* const *str, const GLint *l) {}
static void myglCompileShader(GLuint s) {}
static GLuint myglCreateProgram(void) { static GLuint s=1; return s++; }
static void myglAttachShader(GLuint p, GLuint s) {}
static void myglLinkProgram(GLuint p) {}
static void myglUseProgram(GLuint p) {}
static void myglDeleteShader(GLuint s) {}
static void myglDeleteProgram(GLuint p) {}

// Draw
static void myglDrawArrays(GLenum mode, GLint first, GLsizei count) {
    if (!g_ctx) return;
    id<MTLCommandBuffer> cb = [g_ctx acquireCommandBuffer];
    MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
    rp.colorAttachments[0].loadAction = MTLLoadActionLoad;
    rp.colorAttachments[0].storeAction = MTLStoreActionStore;
    id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:rp];
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:first vertexCount:count];
    [enc endEncoding];
}
static void myglDrawElements(GLenum mode, GLsizei count, GLenum type, const GLvoid *indices) {
    if (!g_ctx) return;
    id<MTLCommandBuffer> cb = [g_ctx acquireCommandBuffer];
    MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
    rp.colorAttachments[0].loadAction = MTLLoadActionLoad;
    rp.colorAttachments[0].storeAction = MTLStoreActionStore;
    id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:rp];
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:count];
    [enc endEncoding];
}
// Queries
static void myglGenQueries(GLsizei n, GLuint *i) {
    static GLuint s=1; for (int j=0;j<n;j++) i[j]=s++;
}
static void myglDeleteQueries(GLsizei n, const GLuint *i) {}
static void myglBeginQuery(GLenum target, GLuint id) {}
static void myglEndQuery(GLenum target) {}
static void myglGetQueryObjectuiv(GLuint id, GLenum pname, GLuint *p) { if(p)*p=1; }

// Get
static void myglGetIntegerv(GLenum pname, GLint *p) {
    switch (pname) {
        case GL_MAX_TEXTURE_SIZE: *p=16384; break;
        case GL_MAX_CUBE_MAP_TEXTURE_SIZE: *p=16384; break;
        case GL_MAX_TEXTURE_IMAGE_UNITS: *p=16; break;
        case GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS: *p=32; break;
        case GL_MAX_VERTEX_ATTRIBS: *p=16; break;
        case GL_MAX_VERTEX_UNIFORM_COMPONENTS: *p=1024; break;
        case GL_MAX_FRAGMENT_UNIFORM_COMPONENTS: *p=1024; break;
        case GL_MAX_RENDERBUFFER_SIZE: *p=16384; break;
        case GL_SAMPLES: *p=4; break;
        case GL_MAX_LIGHTS: *p=8; break;
        case GL_MAX_TEXTURE_UNITS: *p=8; break;
        case GL_MAX_COLOR_ATTACHMENTS: *p=8; break;
        case GL_MAX_DRAW_BUFFERS: *p=8; break;
        default: { void(*f)(GLenum,GLint*)=(void(*)(GLenum,GLint*))getGL("glGetIntegerv");if(f)f(pname,p);else*p=0; }
    }
}
static void myglGetFloatv(GLenum pname, GLfloat *p) {
    switch (pname) {
        case GL_ALIASED_POINT_SIZE_RANGE: p[0]=1;p[1]=256; break;
        case GL_ALIASED_LINE_WIDTH_RANGE: p[0]=1;p[1]=1; break;
        default: { void(*f)(GLenum,GLfloat*)=(void(*)(GLenum,GLfloat*))getGL("glGetFloatv");if(f)f(pname,p); }
    }
}
static const GLubyte* myglGetString(GLenum name) {
    switch (name) {
        case GL_RENDERER: return (const GLubyte*)"Apple M4 GPU (VBoxMetal3D)";
        case GL_VENDOR:   return (const GLubyte*)"Apple";
        case GL_VERSION:  return (const GLubyte*)"4.1 Metal";
        case GL_SHADING_LANGUAGE_VERSION: return (const GLubyte*)"4.10";
        case GL_EXTENSIONS: return (const GLubyte*)"";
    }
    return (const GLubyte*)"";
}
static GLenum myglGetError(void) { return GL_NO_ERROR; }
static void myglFinish(void) { if(g_ctx)[g_ctx waitForGPU]; }
static void myglFlush(void) {}

// ─── Interpose table ─────────────────────────────────────────────────────────

static const InterposeEntry s_interpose[]
    __attribute__((section("__DATA,__interpose"), used)) = {
    { (const void*)myCGLChoosePixelFormat, (const void*)CGLChoosePixelFormat },
    { (const void*)myCGLCreateContext,     (const void*)CGLCreateContext },
    { (const void*)myCGLCreateContext,     (const void*)CGLCreateContext },
    { (const void*)myCGLDestroyContext,    (const void*)CGLDestroyContext },
    { (const void*)myCGLSetCurrentContext, (const void*)CGLSetCurrentContext },
    { (const void*)myCGLFlushDrawable,    (const void*)CGLFlushDrawable },
    { (const void*)myglGenTextures,       (const void*)glGenTextures },
    { (const void*)myglDeleteTextures,    (const void*)glDeleteTextures },
    { (const void*)myglBindTexture,       (const void*)glBindTexture },
    { (const void*)myglTexImage2D,        (const void*)glTexImage2D },
    { (const void*)myglTexSubImage2D,     (const void*)glTexSubImage2D },
    { (const void*)myglActiveTexture,     (const void*)glActiveTexture },
    { (const void*)myglTexParameteri,     (const void*)glTexParameteri },
    { (const void*)myglTexParameterf,     (const void*)glTexParameterf },
    { (const void*)myglGenFramebuffers,   (const void*)glGenFramebuffers },
    { (const void*)myglDeleteFramebuffers,(const void*)glDeleteFramebuffers },
    { (const void*)myglBindFramebuffer,   (const void*)glBindFramebuffer },
    { (const void*)myglFramebufferTexture2D, (const void*)glFramebufferTexture2D },
    { (const void*)myglBlitFramebuffer,   (const void*)glBlitFramebuffer },
    { (const void*)myglGenRenderbuffers,  (const void*)glGenRenderbuffers },
    { (const void*)myglBindRenderbuffer,  (const void*)glBindRenderbuffer },
    { (const void*)myglRenderbufferStorage,(const void*)glRenderbufferStorage },
    { (const void*)myglGenBuffers,        (const void*)glGenBuffers },
    { (const void*)myglDeleteBuffers,     (const void*)glDeleteBuffers },
    { (const void*)myglBindBuffer,        (const void*)glBindBuffer },
    { (const void*)myglBufferData,        (const void*)glBufferData },
    { (const void*)myglViewport,          (const void*)glViewport },
    { (const void*)myglScissor,           (const void*)glScissor },
    { (const void*)myglClearColor,        (const void*)glClearColor },
    { (const void*)myglClearDepth,        (const void*)glClearDepth },
    { (const void*)myglClearStencil,      (const void*)glClearStencil },
    { (const void*)myglClear,             (const void*)glClear },
    { (const void*)myglEnable,            (const void*)glEnable },
    { (const void*)myglDisable,           (const void*)glDisable },
    { (const void*)myglBlendFunc,         (const void*)glBlendFunc },
    { (const void*)myglBlendFuncSeparate, (const void*)glBlendFuncSeparate },
    { (const void*)myglBlendEquation,     (const void*)glBlendEquation },
    { (const void*)myglCreateShader,      (const void*)glCreateShader },
    { (const void*)myglShaderSource,      (const void*)glShaderSource },
    { (const void*)myglCompileShader,     (const void*)glCompileShader },
    { (const void*)myglCreateProgram,     (const void*)glCreateProgram },
    { (const void*)myglAttachShader,      (const void*)glAttachShader },
    { (const void*)myglLinkProgram,       (const void*)glLinkProgram },
    { (const void*)myglUseProgram,        (const void*)glUseProgram },
    { (const void*)myglDeleteShader,      (const void*)glDeleteShader },
    { (const void*)myglDeleteProgram,     (const void*)glDeleteProgram },
    { (const void*)myglDrawArrays,        (const void*)glDrawArrays },
    { (const void*)myglDrawElements,      (const void*)glDrawElements },

    { (const void*)myglGenQueries,        (const void*)glGenQueries },
    { (const void*)myglDeleteQueries,     (const void*)glDeleteQueries },
    { (const void*)myglBeginQuery,        (const void*)glBeginQuery },
    { (const void*)myglEndQuery,          (const void*)glEndQuery },
    { (const void*)myglGetQueryObjectuiv, (const void*)glGetQueryObjectuiv },
    { (const void*)myglGetIntegerv,       (const void*)glGetIntegerv },
    { (const void*)myglGetFloatv,         (const void*)glGetFloatv },
    { (const void*)myglGetString,         (const void*)glGetString },
    { (const void*)myglGetError,          (const void*)glGetError },
    { (const void*)myglFinish,            (const void*)glFinish },
    { (const void*)myglFlush,             (const void*)glFlush },
};

// ─── Init ────────────────────────────────────────────────────────────────────

__attribute__((constructor))
static void init(void) {
    @autoreleasepool {
        g_ctx = VBoxMetalGetGlobalContext();
        if (g_ctx) {
            memset(&s_state, 0, sizeof(s_state));
            s_state.clearColor[3] = 1.0f;
            s_state.clearDepth = 1.0;
            NSLog(@"VBoxMetal3D: Interposed 57 OpenGL→Metal functions");
            NSLog(@"VBoxMetal3D: Device: %@", g_ctx.device.name);
        } else {
            NSLog(@"VBoxMetal3D: WARNING - Metal unavailable, OpenGL passthrough only");
        }
    }
}

__attribute__((destructor))
static void fini(void) {
    NSLog(@"VBoxMetal3D: Unloaded");
}
