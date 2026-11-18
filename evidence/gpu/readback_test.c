/* readback_test.c — how fast can the CPU get a GPU-rendered 1024x768 frame on this PowerVR GX6250?
 * A: glReadPixels straight into malloc'd memory (what virglrenderer does today)
 * B: glReadPixels into a PBO (GL_STREAM_READ) + glMapBufferRange + memcpy
 * C: like B but GL_DYNAMIC_READ, D: like A with GL_BGRA_EXT (if supported)
 * Build (Termux): clang -O2 readback_test.c -o readback_test -L/system/lib64 -lEGL -lGLESv3
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdint.h>

typedef void *EGLDisplay, *EGLConfig, *EGLSurface, *EGLContext;
typedef int32_t EGLint; typedef unsigned EGLBoolean;
extern EGLDisplay eglGetDisplay(void *);
extern EGLBoolean eglInitialize(EGLDisplay, EGLint *, EGLint *);
extern EGLBoolean eglChooseConfig(EGLDisplay, const EGLint *, EGLConfig *, EGLint, EGLint *);
extern EGLSurface eglCreatePbufferSurface(EGLDisplay, EGLConfig, const EGLint *);
extern EGLContext eglCreateContext(EGLDisplay, EGLConfig, EGLContext, const EGLint *);
extern EGLBoolean eglMakeCurrent(EGLDisplay, EGLSurface, EGLSurface, EGLContext);
extern EGLint eglGetError(void);

typedef unsigned GLenum, GLuint, GLbitfield; typedef int GLint, GLsizei; typedef float GLfloat; typedef intptr_t GLintptr, GLsizeiptr;
extern void glGenFramebuffers(GLsizei, GLuint *); extern void glBindFramebuffer(GLenum, GLuint);
extern void glGenRenderbuffers(GLsizei, GLuint *); extern void glBindRenderbuffer(GLenum, GLuint);
extern void glRenderbufferStorage(GLenum, GLenum, GLsizei, GLsizei);
extern void glFramebufferRenderbuffer(GLenum, GLenum, GLenum, GLuint);
extern GLenum glCheckFramebufferStatus(GLenum);
extern void glClearColor(GLfloat, GLfloat, GLfloat, GLfloat); extern void glClear(GLbitfield);
extern void glReadPixels(GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void *);
extern void glGenBuffers(GLsizei, GLuint *); extern void glBindBuffer(GLenum, GLuint);
extern void glBufferData(GLenum, GLsizeiptr, const void *, GLenum);
extern void *glMapBufferRange(GLenum, GLintptr, GLsizeiptr, GLbitfield); extern unsigned char glUnmapBuffer(GLenum);
extern void glFinish(void); extern const unsigned char *glGetString(GLenum); extern GLenum glGetError(void);
extern void glViewport(GLint, GLint, GLsizei, GLsizei);

#define W 1024
#define H 768
#define N 20
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }

int main(void)
{
    EGLDisplay d = eglGetDisplay(0); EGLint ma, mi;
    if (!eglInitialize(d, &ma, &mi)) { printf("eglInitialize failed\n"); return 1; }
    EGLint ca[] = { 0x3024, 8, 0x3023, 8, 0x3022, 8, 0x3021, 8, 0x3033, 0x0001, 0x3040, 0x40, 0x3038 };
    EGLConfig c; EGLint n;
    if (!eglChooseConfig(d, ca, &c, 1, &n) || n < 1) { printf("no config (0x%x)\n", eglGetError()); return 1; }
    EGLint sa[] = { 0x3057, 16, 0x3056, 16, 0x3038 };
    EGLSurface s = eglCreatePbufferSurface(d, c, sa);
    EGLint xa[] = { 0x3098, 3, 0x3038 };
    EGLContext x = eglCreateContext(d, c, 0, xa);
    if (!x || !eglMakeCurrent(d, s, s, x)) { printf("context failed 0x%x\n", eglGetError()); return 1; }
    printf("GL_RENDERER: %s\nGL_VERSION: %s\n", glGetString(0x1F01), glGetString(0x1F02));
    const char *ext = (const char *)glGetString(0x1F03);
    int bgra = ext && strstr(ext, "GL_EXT_read_format_bgra");
    printf("GL_EXT_read_format_bgra: %s\n", bgra ? "yes" : "no");

    GLuint fb, rb; glGenFramebuffers(1, &fb); glBindFramebuffer(0x8D40, fb);
    glGenRenderbuffers(1, &rb); glBindRenderbuffer(0x8D41, rb); glRenderbufferStorage(0x8D41, 0x8058, W, H);
    glFramebufferRenderbuffer(0x8D40, 0x8CE0, 0x8D41, rb);
    if (glCheckFramebufferStatus(0x8D40) != 0x8CD5) { printf("FBO incomplete\n"); return 1; }
    glViewport(0, 0, W, H);
    size_t sz = (size_t)W * H * 4; unsigned char *buf = malloc(sz);
    double t0, dt;

    /* A: direct */
    for (int i = 0; i < 3; i++) { glClearColor(i * .1f, .5f, .2f, 1); glClear(0x4000); glReadPixels(0, 0, W, H, 0x1908, 0x1401, buf); }
    t0 = now();
    for (int i = 0; i < N; i++) { glClearColor((i % 10) * .1f, .3f, .6f, 1); glClear(0x4000); glReadPixels(0, 0, W, H, 0x1908, 0x1401, buf); }
    dt = (now() - t0) / N;
    printf("A direct glReadPixels RGBA : %6.1f ms/frame  (%5.0f MB/s, max %4.0f fps)\n", dt * 1e3, sz / dt / 1e6, 1 / dt);

    /* B/C: PBO */
    GLenum usages[2] = { 0x88E1 /*STREAM_READ*/, 0x88E9 /*DYNAMIC_READ*/ };
    const char *names[2] = { "B PBO STREAM_READ + map    ", "C PBO DYNAMIC_READ + map   " };
    for (int u = 0; u < 2; u++) {
        GLuint pbo; glGenBuffers(1, &pbo); glBindBuffer(0x88EB, pbo); glBufferData(0x88EB, sz, NULL, usages[u]);
        for (int i = 0; i < 3; i++) { glClear(0x4000); glReadPixels(0, 0, W, H, 0x1908, 0x1401, 0); void *p = glMapBufferRange(0x88EB, 0, sz, 1); if (p) memcpy(buf, p, sz); glUnmapBuffer(0x88EB); }
        double tr = 0, tm = 0; t0 = now();
        for (int i = 0; i < N; i++) {
            glClearColor((i % 10) * .1f, .3f, .6f, 1); glClear(0x4000);
            double a = now(); glReadPixels(0, 0, W, H, 0x1908, 0x1401, 0);
            void *p = glMapBufferRange(0x88EB, 0, sz, 1); double b = now();
            if (p) memcpy(buf, p, sz); glUnmapBuffer(0x88EB); double e = now();
            tr += b - a; tm += e - b;
        }
        dt = (now() - t0) / N;
        printf("%s: %6.1f ms/frame  (%5.0f MB/s, max %4.0f fps)  [readpixels+map %.1f ms, memcpy %.1f ms]  err=0x%x\n",
               names[u], dt * 1e3, sz / dt / 1e6, 1 / dt, tr / N * 1e3, tm / N * 1e3, glGetError());
        glBindBuffer(0x88EB, 0);
    }

    /* D: BGRA direct */
    if (bgra) {
        t0 = now();
        for (int i = 0; i < N; i++) { glClearColor((i % 10) * .1f, .3f, .6f, 1); glClear(0x4000); glReadPixels(0, 0, W, H, 0x80E1, 0x1401, buf); }
        dt = (now() - t0) / N;
        printf("D direct glReadPixels BGRA : %6.1f ms/frame  (%5.0f MB/s, max %4.0f fps)\n", dt * 1e3, sz / dt / 1e6, 1 / dt);
    }
    /* E: plain memcpy of cached memory, for reference */
    unsigned char *b2 = malloc(sz); memset(b2, 1, sz); t0 = now(); for (int i = 0; i < N; i++) memcpy(buf, b2, sz); dt = (now() - t0) / N;
    printf("E reference memcpy (cached): %6.1f ms/frame  (%5.0f MB/s)\n", dt * 1e3, sz / dt / 1e6);
    return 0;
}
