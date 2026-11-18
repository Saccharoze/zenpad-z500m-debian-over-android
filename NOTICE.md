# Licenses and credits

Most of this repository is my own work, under the MIT license (see [LICENSE](LICENSE)).
A few parts come from other projects and keep their original license.

| Path | License | Origin |
|---|---|---|
| everything not listed below | MIT | my own work |
| `termux-x11-patch/` | GPL-3.0 ([text](termux-x11-patch/LICENSE)) | changes to [Termux:X11](https://github.com/termux/termux-x11), which is GPL-3.0 |
| `hardware/*.dts` | GPL-2.0 | device trees read from the tablet; they come from the ASUS kernel ([source mirror](https://github.com/Goayandi/android_kernel_asus_z500m)) |

## Credits

- **`ashmem-shm/`** is my own code. It speaks the same shared-memory protocol as the Termux:X11 server, whose code comes from [libandroid-shmem](https://github.com/termux/libandroid-shmem) (BSD-3-Clause).
- **Bootloader unlock**: the unlock tool for this tablet was written by "diplomatic" on XDA. It is not included here; see the [original thread](https://xdaforums.com/t/tool-unlock-bootloader-in-asus-zenpad-3s-10-z500m-p027.3730909/).
- **Recovery**: the unofficial TWRP 3.2.1 port for the Z500M by "rakomancha" and "diplomatic" on XDA. Not included here.
- **Root**: [Magisk](https://github.com/topjohnwu/Magisk).
- **Debian root filesystem**: [images.linuxcontainers.org](https://images.linuxcontainers.org/).
- **Android apps used**: [Termux](https://github.com/termux/termux-app), [Termux:Boot](https://github.com/termux/termux-boot), [Termux:X11](https://github.com/termux/termux-x11).
