# Termux:X11 on Android 7: the patch

[Termux:X11](https://github.com/termux/termux-x11) is an X server packaged as an Android app.
The upstream nightly at commit `f1d98342` does not connect on this tablet's Android 7.0.
This folder holds the fixes, as diffs, and the script that rebuilds the app.

License: GPL-3.0, like Termux:X11 ([LICENSE](LICENSE)).

## Bug 1: the server can't announce itself

When it starts without an Android "Context", the server falls back to a "manual broadcast".
That code uses a method signature that only exists from Android 8 on, and the error is swallowed.

Starting the server with `OLD_CONTEXT=1`, a switch that already exists upstream, avoids that path.
No code change is needed: see [`android/termux/bin/zenpad-x11.sh`](../android/termux/bin/zenpad-x11.sh).

## Bug 2: the app always thinks it's connected

`LorieView.connected()` is marked `@CriticalNative`, a speed-up that Android 7 ignores.
The native function then reads the wrong argument as its pointer, gets garbage, and answers "connected".
The app never asks for the X socket, and the screen shows "Not connected", then "X server stalled".

[`patches/LorieView.smali.diff`](patches/LorieView.smali.diff) makes `connected()` return a Java flag
that `connect(int)` sets, below Android 8 (API 26).

## Patch 2: hide Android's mouse pointer

With a USB mouse, Android's own arrow stayed visible next to the X cursor.
[`patches/MainActivity.smali.diff`](patches/MainActivity.smali.diff) gives the view a fully transparent pointer icon.

It has no effect. `dumpsys SurfaceFlinger` still shows the 44×56 pointer layer: this ASUS build ignores
every app-side pointer change. The patch is harmless and stays in.

What worked is a fully transparent cursor theme on the Linux side, built by
[`tools/mkinvis-cursor-theme.py`](../tools/mkinvis-cursor-theme.py). Only Android's arrow remains.

## Rebuild the app

You need `apktool` 2.7.0, Python 3, OpenSSL, and the upstream universal debug nightly APK (commit `f1d98342`).

```sh
apktool d -r termux-x11.apk -o dec
patch "$(find dec -name LorieView.smali)"    patches/LorieView.smali.diff
patch "$(find dec -name MainActivity.smali)" patches/MainActivity.smali.diff
apktool b dec -o rebuilt.apk && unzip -o rebuilt.apk classes.dex -d dex

# your own signing key (keep it: updates must be signed with the same key)
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=termux-x11-android7" -keyout key.pem -out cert.pem

python3 build_apk.py termux-x11.apk dex termux-x11-android7.apk key.pem cert.pem
```

`build_apk.py` puts the new code into the original APK, keeps the native libraries stored
uncompressed and 4096-byte aligned, and signs it (v1 signature).

## One more step on the Termux side

The Termux package `termux-x11-nightly` installs a small loader, `$PREFIX/libexec/termux-x11/loader.apk`,
that checks the app's signature. Re-signing changes that signature, so the loader's expected hash
was patched to match the new certificate. The package is then put on hold (`apt-mark hold termux-x11-nightly`),
so an update can't undo it.

## Also needed in the Debian chroot

`LIBGL_DRI3_DISABLE=1`: Termux:X11 offers DRI3, but Mesa then waits forever on shared "fences"
from inside the chroot, and GTK apps hang. See [`chroot/root/start-desktop-x11.sh`](../chroot/root/start-desktop-x11.sh).
