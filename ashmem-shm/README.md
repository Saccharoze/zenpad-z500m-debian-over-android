# ashmem-shm: MIT-SHM for the Debian chroot on Termux:X11 (Android 7, no SysV IPC)

The ZenPad kernel has no SysV IPC (`/proc/sysvipc` missing), so X clients in the chroot could not use
MIT-SHM and pushed every frame through the X socket. The Termux:X11 server has its own SysV-shm emulation
(ashmem regions handed out over abstract unix sockets `@/dev/shm/%08x`, from libandroid-shmem).
`ashmem_shm.c` implements the same protocol for glibc programs, so the server can attach their segments.
ashmem fds (label `ashmem_device`) pass SELinux where memfds from the chroot (`tmpfs`) are denied.

Installed in the chroot: `/usr/local/lib/libashmem-shm.so` (source `/usr/local/src/ashmem_shm.c`),
loaded for every chroot program via `/etc/ld.so.preload`. Debug: `ASHMEM_SHM_DEBUG=1`.
Disable: remove `/etc/ld.so.preload` (chroot) and restart the desktop.

Build: `gcc -shared -fPIC -O2 -Wall -o /usr/local/lib/libashmem-shm.so ashmem_shm.c -lpthread`

## Measurements (glxgears 1000x700, vblank off)
| path | FPS | X server CPU | notes |
|---|---|---|---|
| llvmpipe, no SHM | ~37 | 20% | frame pushed through the socket |
| llvmpipe + ashmem-shm | ~62 | 12% | X server cost per frame -65% |
| virgl (virpipe), no SHM | ~29 | 15% | |
| virgl + ashmem-shm | ~32 | 7% | bottleneck = PowerVR readback in the virgl server |

GPU readback ([`evidence/gpu/readback_test.c`](../evidence/gpu/readback_test.c), 1024x768 on PowerVR GX6250): glReadPixels RGBA 9.7 ms,
PBO 10.6 ms (no gain), **BGRA 88 ms**. virgl spends ~22 ms/frame in `glReadnPixels → PVRSRVDeviceMemCopy`.
Firefox SW WebRender scrolling a heavy page: 4–5.5 cores busy, 10–25 fps; display path is a small share.
Firefox HW WebRender via virpipe: GL context creation fails (EGL 0x3005/0x3009; GLX → falls back to SW).
