# Performance and power

The CPU draws everything. The GPU only composites Android's layers.

## Where the resources go

Measured with YouTube playing in Firefox, over 20 s
([`evidence/how-measured/meas.sh`](../evidence/how-measured/meas.sh)):

| | RAM (PSS) | CPU (cores, of 6) |
|---|---|---|
| Firefox | 1,112 MB | 1.5 |
| Android (system 123 MB, apps 168 MB) | 291 MB | 0.24 |
| Termux side (X server, PulseAudio) | 33 MB | 0.23 |
| LXDE | 27 MB | about 0 |
| Kernel threads | | 0.07 |
| Boot script | about 1 MB | 0.03 |

The whole tablet was 43% busy, by `/proc/stat`, which also counts interrupts and I/O wait. The GPU stayed between 0 and 24% load, at its lowest clock (253 MHz).
Of the 3,946 MB of usable RAM, 1.2 GB was free and 1.0 GB was cache.

## Software rendering beats the GPU bridge

The GPU bridge tried here is virgl: Mesa's `virpipe` driver in the chroot sends OpenGL to
`virgl_test_server_android` in Termux, which runs it on Android's PowerVR driver
([`evidence/gpu/`](../evidence/gpu/zenpad-virgl.sh)). Firefox scrolling a page
([`evidence/raw/ffbench3.out`](../evidence/raw/ffbench3.out)):

| | Software (llvmpipe) | virgl |
|---|---|---|
| Normal page | 30 FPS, 30% of a core | 21 FPS, 73% of a core |
| Heavy page | 8 to 9 FPS, 76% of a core | not recorded, the run stopped |

The test profile had the 30 FPS cap from `user.js` (below), so software reached the cap on the normal page.

Each frame has to come back from the GPU to the CPU, and that's slow on this PowerVR GX6250.
Reading back a 1024×768 frame took 9.7 ms with `glReadPixels` in RGBA, 10.6 ms through
a pixel buffer, and 88 ms in BGRA ([`evidence/gpu/readback_test.c`](../evidence/gpu/readback_test.c)).
Inside the virgl server, reading frames back took about 22 ms per frame. Software rendering stays.

## Drawing less

- The desktop renders at 800×600 ([Display](03-display.md)).
- Firefox, in [`user.js`](../chroot/root/.config/mozilla/firefox/default-esr/user.js), copied into the profile folder
  (`/root/.config/mozilla/firefox/<random>.default-esr/`, created at Firefox's first start): AV1 and VP9 off,
  so YouTube serves H.264. 30 FPS cap. Two content processes, no per-site isolation. No smooth scrolling
  or animations. Background tabs unloaded when memory is low. Telemetry, Pocket and studies off. Zoom 0.85
  for the small screen.
- uBlock Origin, installed by [policy](../chroot/etc/firefox/policies/policies.json).

## CPU tuning at boot

For responsiveness, the boot script also changes a few kernel settings, at runtime only. Thermal limits
are untouched. `touch /data/local/tmp/zenpad-tune.off` skips it at the next boot.

| Setting | Default | Set to |
|---|---|---|
| `go_hispeed_load`, interactive governor of the four A53 cores | 99 | 85 |
| `hispeed_freq`, same governor | 1703000 | 1300000 |
| `target_loads`, same governor | 90 | 80 |
| MediaTek hotplug `up_threshold` / `down_threshold` | 80 / 70 | 65 / 50 |
| MediaTek hotplug `down_times` | 10 | 20 |
| eMMC I/O scheduler | cfq | deadline |

## Power

The charger chip (SMB1351) decides how much current to draw from what it detects on USB. Measured with
[`chg.sh`](../evidence/how-measured/chg.sh) and [`batt.sh`](../evidence/how-measured/batt.sh):

| | Detected as | Input limit | Battery |
|---|---|---|---|
| PC USB port | `STANDARD_HOST` | 500 mA | drains under load: 83% to 65% in about 2.5 h |
| USB-A wall charger | `STANDARD_CHARGER` | 2000 mA | charges |

So the tablet needs a wall charger.

On battery, with the desktop idle and the backlight at 9 out of 255, the fuel gauge read about 0.47 A at 4.03 V,
so about 1.9 W (30 samples over 60 s, [`evidence/raw/power.raw`](../evidence/raw/power.raw), from
[`powertest.sh`](../evidence/how-measured/powertest.sh)).
The test was meant to go on with Firefox and video, but stopped after this first phase.

## Don't

On this firmware, `settings put global background_process_limit 0` sends the tablet into a boot loop. To get out, catch the
few seconds Android stays up and run `settings put global background_process_limit -1` over adb.

---

Previous: [Boot and self-healing](05-boot-and-self-healing.md) · [All steps](../README.md#steps) · Next: [Why not native Debian](07-why-not-native-debian.md)
