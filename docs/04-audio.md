# Audio

Debian's sound goes over TCP to a PulseAudio server running in the Termux app, which plays it through
Android's OpenSL ES, so through Android's own audio service. Nothing in the chroot touches the sound hardware.

```mermaid
flowchart LR
  APP["Firefox<br/>(chroot)"] -- "tcp:127.0.0.1:4713" --> PA["PulseAudio<br/>in the Termux app"]
  PA -- "OpenSL ES" --> AS["Android audioserver"] --> HW["RT5659 codec"]
```

Video (9 s): [YouTube playing with sound](img/youtube.mp4).

## Why not ALSA

Driving the codec directly (stopping `audioserver`, routing the RT5659 by hand, a PulseAudio in the chroot
on `/dev/snd`) hung the audio hardware and rebooted the tablet. All sound goes through Android instead.

## PulseAudio in Termux

```sh
pkg install pulseaudio
```

Termux's PulseAudio (17.0) loads `module-sles-sink` by default: an output on OpenSL ES. It has to run
inside the Termux app. Started from a root shell with Termux's user ID, it only got a null sink.

[`android/termux/bin/zenpad-audio.sh`](../android/termux/bin/zenpad-audio.sh), in `~/bin` in Termux, starts it.
Termux:Boot runs it after boot, and the boot script asks Termux to run it again whenever PulseAudio is down
([Boot and self-healing](05-boot-and-self-healing.md)). It starts the server with no idle exit, then opens
TCP port 4713 for the chroot:

```sh
pulseaudio --start --exit-idle-time=-1
pactl load-module module-native-protocol-tcp port=4713 listen=127.0.0.1 auth-anonymous=1
```

The TCP module has to be loaded after the start: `--load=` on the start line didn't work.
Before starting, the script kills any stuck daemon and removes stale runtime files, which otherwise block the start.

If a root-owned file ends up in Termux's home (after tests run as root), PulseAudio can't write its
database and aborts. From a root shell:

```sh
chown -R $(stat -c %u:%g /data/data/com.termux) /data/data/com.termux/files/home
```

## The chroot side

[`chroot/etc/pulse/client.conf`](../chroot/etc/pulse/client.conf), also copied to `/root/.config/pulse/client.conf`:

```
default-server = tcp:127.0.0.1:4713
autospawn = no
daemon-binary = /bin/true
```

The chroot's own PulseAudio server never runs: `autospawn = no` and `daemon-binary = /bin/true` stop programs
from starting it. Never start `pulseaudio` in the chroot by hand either: it would open the sound card directly,
which is the path that reboots the tablet.

To check the path from the chroot (`apt-get install pulseaudio-utils`):

```sh
pactl info                    # should name the Termux server
head -c 52920 /dev/zero | timeout 10 pacat --raw --format=s16le --rate=44100 --channels=2    # 0.3 s of silence
```

## When the output stalls

Sometimes YouTube stops with "If playback doesn't begin shortly, try restarting your device".
PulseAudio is up (`pactl info` answers), but its OpenSL output has stopped taking audio:
1.5 s of silence sent with `pacat` never finishes. Firefox times video on the audio clock, so the video freezes too.

What triggers it is still unknown. An `audioserver` restart, device sleep and PulseAudio's idle suspend were ruled out.
Killing PulseAudio fixes it: the boot script starts it again. A Firefox that was playing during the stall
can stay frozen and needs a restart.

The boot script now runs the silence test about once a minute. A stall it caught:

```
11-16 10:13:38 audio probe failed (1/2)
11-16 10:15:04 audio probe failed (2/2)
11-16 10:15:04 audio stalled -> restarting PulseAudio
11-16 10:15:30 audio down -> start
```

## Volume

The hardware volume buttons don't change the level. The PulseAudio sink volume, the stream volume and
Android's media volume were all tried, with no audible change. Volume is set in the app that plays.

---

Previous: [Display](03-display.md) · [All steps](../README.md#steps) · Next: [Boot and self-healing](05-boot-and-self-healing.md)
