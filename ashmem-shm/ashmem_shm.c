/*
 * ashmem_shm.c — SysV shared memory (shmget/shmat/shmdt/shmctl) for glibc programs
 * running in a chroot on Android, compatible with the shm emulation built into the
 * Termux:X11 server (lorie/shm/shmem.c, itself derived from Termux's libandroid-shmem).
 *
 * Why: the ZenPad's Android kernel has no SysV IPC, so X clients (Mesa, Firefox, GTK/cairo)
 * cannot use MIT-SHM and push every frame through the X socket. With this library
 * LD_PRELOADed, segments are Android ashmem regions; the X server fetches them over an
 * abstract unix socket "\0/dev/shm/%08x" (socket id = shmid >> 16) and maps them.
 *
 * Wire protocol (must match the server):
 *   requester -> owner : int shmid
 *   owner -> requester : key_t key, then the ashmem fd via SCM_RIGHTS (1 dummy byte)
 *   requester gets the size with ASHMEM_GET_SIZE.
 *
 * Build: gcc -shared -fPIC -O2 -o libashmem-shm.so ashmem_shm.c -lpthread
 */
#define _GNU_SOURCE
#include <errno.h>
#include <stddef.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/ipc.h>
#include <sys/mman.h>
#include <sys/shm.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

/* linux/ashmem.h */
#define ASHMEM_NAME_LEN 256
#define __ASHMEMIOC 0x77
#define ASHMEM_SET_NAME _IOW(__ASHMEMIOC, 1, char[ASHMEM_NAME_LEN])
#define ASHMEM_SET_SIZE _IOW(__ASHMEMIOC, 3, size_t)
#define ASHMEM_GET_SIZE _IO(__ASHMEMIOC, 4)

#define SOCKNAME "/dev/shm/%08x"
#define ROUND_UP(n, s) ((((n) + (s) - 1) / (s)) * (s))

typedef struct {
    int id;
    void *addr;
    int fd;
    size_t size;
    bool rm;      /* IPC_RMID requested while attached */
    key_t key;
} seg_t;

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static seg_t *segs;
static size_t nsegs;
static int sock_id;          /* our 16-bit socket id, 0 = not listening yet */
static pid_t owner_pid;      /* pid the state belongs to (fork handling) */
static pthread_t listener;
static unsigned counter;
static int debug = -1;

#define DBG(...) do { if (debug < 0) debug = getenv("ASHMEM_SHM_DEBUG") != NULL; \
    if (debug) { fprintf(stderr, "[ashmem-shm %d] ", getpid()); fprintf(stderr, __VA_ARGS__); fputc('\n', stderr); } } while (0)

/* fork(): hold the lock across fork so the child never inherits it locked, then reset
 * the child's state (its own listener/socket id; inherited segments stay valid fds). */
static void atfork_prepare(void) { pthread_mutex_lock(&lock); }
static void atfork_parent(void) { pthread_mutex_unlock(&lock); }
static void atfork_child(void)
{
    owner_pid = getpid();
    sock_id = 0;
    listener = 0;
    pthread_mutex_unlock(&lock);
}
__attribute__((constructor)) static void init(void)
{
    owner_pid = getpid();
    pthread_atfork(atfork_prepare, atfork_parent, atfork_child);
}
static void check_fork(void) { }

static int send_fd(int s, int fd)
{
    char c = '!';
    struct iovec iov = { .iov_base = &c, .iov_len = 1 };
    union { struct cmsghdr h; char buf[CMSG_SPACE(sizeof(int))]; } u;
    struct msghdr m = { .msg_iov = &iov, .msg_iovlen = 1, .msg_control = u.buf, .msg_controllen = sizeof(u.buf) };
    struct cmsghdr *cm = CMSG_FIRSTHDR(&m);
    cm->cmsg_level = SOL_SOCKET; cm->cmsg_type = SCM_RIGHTS; cm->cmsg_len = CMSG_LEN(sizeof(int));
    memcpy(CMSG_DATA(cm), &fd, sizeof(int));
    return sendmsg(s, &m, 0) >= 0 ? 0 : -1;
}

static int recv_fd(int s)
{
    char c;
    struct iovec iov = { .iov_base = &c, .iov_len = 1 };
    union { struct cmsghdr h; char buf[CMSG_SPACE(sizeof(int))]; } u;
    struct msghdr m = { .msg_iov = &iov, .msg_iovlen = 1, .msg_control = u.buf, .msg_controllen = sizeof(u.buf) };
    if (recvmsg(s, &m, 0) <= 0) return -1;
    struct cmsghdr *cm = CMSG_FIRSTHDR(&m);
    if (!cm || cm->cmsg_type != SCM_RIGHTS) return -1;
    int fd; memcpy(&fd, CMSG_DATA(cm), sizeof(int));
    return fd;
}

static int find(int shmid)
{
    for (size_t i = 0; i < nsegs; i++) if (segs[i].id == shmid) return (int)i;
    return -1;
}

static void drop(int i)
{
    if (segs[i].fd >= 0) close(segs[i].fd);
    nsegs--;
    memmove(&segs[i], &segs[i + 1], (nsegs - i) * sizeof(seg_t));
}

static void *serve(void *arg)
{
    int ls = (int)(intptr_t)arg, c;
    while ((c = accept(ls, NULL, NULL)) != -1) {
        int shmid;
        if (recv(c, &shmid, sizeof shmid, MSG_WAITALL) == sizeof shmid) {
            pthread_mutex_lock(&lock);
            int i = find(shmid);
            if (i >= 0) {
                if (write(c, &segs[i].key, sizeof(key_t)) == sizeof(key_t))
                    send_fd(c, segs[i].fd);
                DBG("served shmid 0x%x (fd %d) to a peer", shmid, segs[i].fd);
            } else DBG("peer asked for unknown shmid 0x%x", shmid);
            pthread_mutex_unlock(&lock);
        }
        close(c);
    }
    DBG("listener stopped: %s", strerror(errno));
    return NULL;
}

static int start_listener(void)
{
    int s = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (s < 0) return -1;
    for (int i = 0; i < 4096; i++) {
        struct sockaddr_un a; memset(&a, 0, sizeof a);
        a.sun_family = AF_UNIX;
        int id = (getpid() + i) & 0xffff;
        if (id == 0) continue;
        snprintf(&a.sun_path[1], sizeof a.sun_path - 1, SOCKNAME, id);
        socklen_t len = offsetof(struct sockaddr_un, sun_path) + 1 + strlen(&a.sun_path[1]);
        if (bind(s, (struct sockaddr *)&a, len) == 0 && listen(s, 8) == 0) {
            sock_id = id;
            pthread_attr_t at; pthread_attr_init(&at); pthread_attr_setdetachstate(&at, PTHREAD_CREATE_DETACHED);
            int r = pthread_create(&listener, &at, serve, (void *)(intptr_t)s);
            pthread_attr_destroy(&at);
            if (r != 0) { close(s); sock_id = 0; return -1; }
            DBG("listening on @" SOCKNAME, id);
            return 0;
        }
    }
    close(s);
    return -1;
}

static int fetch_remote(int shmid)   /* caller holds lock */
{
    struct sockaddr_un a; memset(&a, 0, sizeof a);
    a.sun_family = AF_UNIX;
    snprintf(&a.sun_path[1], sizeof a.sun_path - 1, SOCKNAME, (unsigned)shmid >> 16);
    socklen_t len = offsetof(struct sockaddr_un, sun_path) + 1 + strlen(&a.sun_path[1]);
    int s = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (s < 0) return -1;
    key_t key; int fd = -1;
    if (connect(s, (struct sockaddr *)&a, len) != 0 ||
        send(s, &shmid, sizeof shmid, 0) != sizeof shmid ||
        recv(s, &key, sizeof key, MSG_WAITALL) != sizeof key ||
        (fd = recv_fd(s)) < 0) {
        DBG("fetch of remote shmid 0x%x failed: %s", shmid, strerror(errno));
        close(s); return -1;
    }
    close(s);
    int size = ioctl(fd, ASHMEM_GET_SIZE, NULL);
    if (size <= 0) { close(fd); return -1; }
    segs = realloc(segs, (nsegs + 1) * sizeof(seg_t));
    segs[nsegs] = (seg_t){ .id = shmid, .addr = NULL, .fd = fd, .size = (size_t)size, .rm = false, .key = key };
    return (int)nsegs++;
}

int shmget(key_t key, size_t size, int flags)
{
    (void)flags;
    pthread_mutex_lock(&lock);
    check_fork();
    if (key != IPC_PRIVATE) {       /* keyed segments are not needed by X clients */
        pthread_mutex_unlock(&lock);
        errno = ENOSYS; return -1;
    }
    if (!sock_id && start_listener() != 0) {
        pthread_mutex_unlock(&lock);
        errno = ENOMEM; return -1;
    }
    size = ROUND_UP(size, (size_t)getpagesize());
    int fd = open("/dev/ashmem", O_RDWR | O_CLOEXEC);
    if (fd < 0) { pthread_mutex_unlock(&lock); return -1; }
    char name[ASHMEM_NAME_LEN] = {0};
    counter = (counter + 1) & 0x7fff;
    if (counter == 0) counter = 1;
    int shmid = sock_id * 0x10000 + (int)counter;
    snprintf(name, sizeof name, SOCKNAME "-%d", sock_id, (int)counter);
    if (ioctl(fd, ASHMEM_SET_NAME, name) < 0 || ioctl(fd, ASHMEM_SET_SIZE, size) < 0) {
        int e = errno; close(fd); pthread_mutex_unlock(&lock); errno = e; return -1;
    }
    segs = realloc(segs, (nsegs + 1) * sizeof(seg_t));
    segs[nsegs++] = (seg_t){ .id = shmid, .addr = NULL, .fd = fd, .size = size, .rm = false, .key = key };
    DBG("shmget size %zu -> shmid 0x%x", size, shmid);
    pthread_mutex_unlock(&lock);
    return shmid;
}

void *shmat(int shmid, const void *addr, int flg)
{
    pthread_mutex_lock(&lock);
    check_fork();
    int i = find(shmid);
    if (i < 0 && ((unsigned)shmid >> 16) != (unsigned)sock_id) i = fetch_remote(shmid);
    if (i < 0) { pthread_mutex_unlock(&lock); errno = EINVAL; return (void *)-1; }
    if (!segs[i].addr) {
        void *p = mmap((void *)addr, segs[i].size, PROT_READ | ((flg & SHM_RDONLY) ? 0 : PROT_WRITE), MAP_SHARED, segs[i].fd, 0);
        segs[i].addr = (p == MAP_FAILED) ? NULL : p;
    }
    void *r = segs[i].addr;
    pthread_mutex_unlock(&lock);
    return r ? r : (void *)-1;
}

int shmdt(const void *addr)
{
    pthread_mutex_lock(&lock);
    check_fork();
    for (size_t i = 0; i < nsegs; i++) {
        if (segs[i].addr == addr) {
            munmap(segs[i].addr, segs[i].size);
            segs[i].addr = NULL;
            if (segs[i].rm || ((unsigned)segs[i].id >> 16) != (unsigned)sock_id) drop((int)i);
            break;
        }
    }
    pthread_mutex_unlock(&lock);
    return 0;
}

int shmctl(int shmid, int cmd, struct shmid_ds *buf)
{
    pthread_mutex_lock(&lock);
    check_fork();
    int i = find(shmid), ret = 0;
    if (cmd == IPC_RMID) {
        if (i >= 0) { if (segs[i].addr) segs[i].rm = true; else drop(i); }
    } else if (cmd == IPC_STAT) {
        if (i < 0 || !buf) { errno = EINVAL; ret = -1; }
        else {
            memset(buf, 0, sizeof *buf);
            buf->shm_segsz = segs[i].size;
            buf->shm_nattch = 1;
            buf->shm_perm.__key = segs[i].key;
            buf->shm_perm.uid = buf->shm_perm.cuid = geteuid();
            buf->shm_perm.gid = buf->shm_perm.cgid = getegid();
            buf->shm_perm.mode = 0666;
        }
    } else { errno = EINVAL; ret = -1; }
    pthread_mutex_unlock(&lock);
    return ret;
}
