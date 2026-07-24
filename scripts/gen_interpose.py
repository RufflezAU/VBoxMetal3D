#!/usr/bin/env python3
"""Generate UTMetal3D interpose source from epoxy function list."""

import subprocess, re, sys

# Get virglrenderer's epoxy imports
result = subprocess.run(
    ["nm", "-g",
     "/Applications/UTM.app/Contents/Frameworks/virglrenderer.1.framework/virglrenderer.1"],
    capture_output=True, text=True)
symbols = result.stdout

funcs = []
for line in symbols.splitlines():
    m = re.search(r'U\s+_epoxy_(\S+)', line)
    if m:
        funcs.append(m.group(1))

# Remove duplicates
funcs = sorted(set(funcs))
print(f"/* Auto-generated from {len(funcs)} epoxy imports */")

# Core functions that get full tracing
core_funcs = {
    # EGL
    'eglGetDisplay', 'eglInitialize', 'eglChooseConfig', 'eglCreateContext',
    'eglMakeCurrent', 'eglSwapBuffers', 'eglCreateWindowSurface',
    'eglCreatePbufferSurface', 'eglDestroySurface', 'eglDestroyContext',
    'eglTerminate', 'eglBindAPI', 'eglGetConfigAttrib', 'eglGetProcAddress',
    'eglGetError', 'eglGetCurrentContext', 'eglQueryString',
    # GL program/shader
    'glCreateProgram', 'glDeleteProgram', 'glCreateShader', 'glDeleteShader',
    'glShaderSource', 'glCompileShader', 'glAttachShader', 'glLinkProgram',
    'glUseProgram', 'glGetAttribLocation', 'glGetUniformLocation',
    'glGetShaderiv', 'glGetShaderInfoLog', 'glGetProgramiv', 'glGetProgramInfoLog',
    # GL texture
    'glGenTextures', 'glBindTexture', 'glDeleteTextures',
    'glTexImage2D', 'glTexSubImage2D', 'glTexParameteri', 'glTexParameterf',
    'glActiveTexture', 'glGenerateMipmap',
    # GL framebuffer
    'glGenFramebuffers', 'glBindFramebuffer', 'glDeleteFramebuffers',
    'glFramebufferTexture2D', 'glFramebufferRenderbuffer',
    'glCheckFramebufferStatus',
    'glGenRenderbuffers', 'glBindRenderbuffer', 'glDeleteRenderbuffers',
    'glRenderbufferStorage', 'glRenderbufferStorageMultisampleEXT',
    # GL buffer
    'glGenBuffers', 'glBindBuffer', 'glDeleteBuffers',
    'glBufferData', 'glBufferSubData', 'glMapBufferRange', 'glUnmapBuffer',
    # GL state
    'glViewport', 'glScissor', 'glClear', 'glClearColor', 'glClearDepth',
    'glClearDepthf', 'glClearStencil', 'glEnable', 'glDisable',
    'glBlendFunc', 'glBlendEquation', 'glBlendColor',
    'glDepthFunc', 'glDepthMask', 'glCullFace', 'glFrontFace',
    'glColorMask', 'glPolygonOffset', 'glLineWidth', 'glPixelStorei',
    # GL draw
    'glDrawArrays', 'glDrawElements', 'glFlush', 'glFinish',
    # GL vertex
    'glVertexAttribPointer', 'glEnableVertexAttribArray', 'glDisableVertexAttribArray',
    'glBindVertexArray', 'glGenVertexArrays', 'glDeleteVertexArrays',
    # GL misc
    'glGetError', 'glGetString', 'glGetIntegerv', 'glGetFloatv',
    'glGetBooleanv', 'glGetInteger64v', 'glReadPixels',
    'glUniform1i', 'glUniform1f', 'glUniform2f', 'glUniform3f', 'glUniform4f',
    'glUniform1iv', 'glUniform2iv', 'glUniform3iv', 'glUniform4iv',
    'glUniform1fv', 'glUniform2fv', 'glUniform3fv', 'glUniform4fv',
    'glUniformMatrix4fv', 'glUniformMatrix3fv',
    'glBindAttribLocation', 'glGetActiveUniform',
}

# Generate source
out = []
out.append('#include <dlfcn.h>\n')
out.append('#define NO_TRACE(name) ((void)(name))')
out.append('')

# Generate extern declarations and real_* pointers for all core functions
for f in sorted(funcs):
    if f in core_funcs:
        # Strip gl/egl prefix for pointer naming
        clean = f.replace('egl', 'egl_').replace('gl', 'gl_')
        out.append(f'static void *(*real_{clean})() = NULL;')
        out.append(f'extern void epoxy_{f}(void);')

out.append('')
out.append('// Interpose table entries')
out.append('static const InterposeEntry s_interpose[]')
out.append('    __attribute__((section("__DATA,__interpose"), used)) = {')

for f in sorted(funcs):
    if f in core_funcs:
        out.append(f'    {{ (const void*)my_epoxy_{f}, (const void*)epoxy_{f} }},')

out.append('};')
out.append('')

# Generate replacement functions
for f in sorted(funcs):
    if f in core_funcs:
        clean = f.replace('egl', 'egl_').replace('gl', 'gl_')
        out.append(f'''
static void my_epoxy_{f}(void) {{
    if (!real_{clean}) real_{clean} = (void(*)())dlsym(RTLD_DEFAULT, "epoxy_{f}");
    NSLog(@"UTMetal3D: → {f}");
    real_{clean}();
}}''')

print('\n'.join(out))
