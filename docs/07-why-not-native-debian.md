# Why not native Debian

Before settling on the chroot, I studied replacing Android with a mainline kernel and Debian. Nothing was
booted: this is a study, from the device tree read on the running tablet, the ASUS kernel source, and the
state of mainline Linux in November 2026.

## The hardware

From [`hardware/p027-live.dts`](../hardware/p027-live.dts) (the device tree as booted) and
[`hardware/hw-inventory.txt`](../hardware/hw-inventory.txt) (made by [`hwinv.sh`](../evidence/how-measured/hwinv.sh)):

| Part | Chip | In mainline Linux |
|---|---|---|
| SoC | MT8176 (MT8173 family), 4× Cortex-A53 + 2× Cortex-A72 | yes, from the MT8173 Chromebooks |
| Panel | Tianma 1536×2048, NT35523 controller, dual DSI | no: no dual DSI on MT8173, no panel driver |
| Wi-Fi, Bluetooth | MT6630 on SDIO | no: the vendor driver only builds for the 3.18 kernel |
| GPU | PowerVR GX6250 | patches under review (v4, July 2026) |
| Charger, fuel gauge | SMB1351, MT6397 gauge | no driver (the rest of the MT6397 PMIC is supported) |
| Audio | RT5659 codec, MT8173 AFE | codec and AFE yes, the board driver no |
| Touch | Atmel maXTouch | yes |

## The display

The bootloader (LK) already turns the panel on to show the logo. Linux could draw into LK's framebuffer
(`simple-framebuffer`) from the first boot. But with no driver for the panel, nothing could set it up again
once it was powered off. So no suspend: only the backlight (LP8557, which has a mainline driver) can go off.

## The other routes

- The ASUS 3.18 kernel with Debian and no Android: its display driver isn't standard DRM/KMS, the GPU driver
  only exists for Android, and sound only worked through Android (driving the codec directly rebooted the
  tablet, see [Audio](04-audio.md)). Not tried further.
- Current Halium and Droidian run Linux on top of Android's drivers, but need Android 9 or later.
  This tablet stops at Android 7.

## Native against the chroot

| | Native | Chroot |
|---|---|---|
| CPU and RAM | Android's share comes back | Android takes about 0.3 GB and 0.24 core |
| Graphics | software | software (the GPU bridge was slower) |
| Wi-Fi, Bluetooth | none built in | yes |
| Battery level, charge control | not until drivers are written | yes |
| Suspend | no | yes |
| Audio | after a driver port | yes |

For a tablet used every day, the chroot wins.

## What a boot image must look like

Read from the stock boot image and from what LK does to it (compare the device tree inside the boot image,
[`hardware/p027-bootimg.dts`](../hardware/p027-bootimg.dts), with the one as booted):

- The stock command line holds `bootopt=64S3,32N2,64N2`, which LK reads to start the kernel in 64-bit mode.
- The kernel is `Image.gz` with the device tree appended, loaded at `0x40080000`. Decompressed, it must end
  before `0x44000000`, where LK puts the initramfs.
- LK edits the device tree before booting it, and adds three reserved memory regions, one of them the TrustZone
  region at `0xfe800000`. The device tree needs a `/reserved-memory` node, and should declare these regions
  itself in case LK doesn't.
- `fastboot boot` tests an image from RAM without writing anything ([Unlock and root](01-unlock-and-root.md)).

[`hardware/inspect-bootimg.py`](../hardware/inspect-bootimg.py) checks a boot image against these rules.

The closest prior art is a 2022 mainline attempt on the Amazon Fire HD 10 (2017), which has an MT8173
and the same kind of LK bootloader ([suez-linux](https://github.com/knot126/suez-linux)). It stopped at the
first boot, with no way to see the kernel's output.

Sources: [ASUS kernel source](https://github.com/Goayandi/android_kernel_asus_z500m),
[PowerVR GX6250 patches](https://lkml.iu.edu/2607.3/12558.html),
[XDA MT8173/MT8176 development thread](https://xdaforums.com/t/mediatek-mt8173-mt8176-development.3791009/).

---

Previous: [Performance and power](06-performance-and-power.md) · [All steps](../README.md#steps)
