#!/data/data/com.termux/files/usr/bin/sh
# PulseAudio for the Debian chroot: OpenSL ES sink -> Android audio, TCP 4713 for chroot clients
export XDG_RUNTIME_DIR=$PREFIX/tmp
if pactl list short modules 2>/dev/null | grep -q native-protocol-tcp; then exit 0; fi
# unreachable/stuck daemon (e.g. its socket was wiped with $PREFIX/tmp) -> kill it hard
pulseaudio -k 2>/dev/null; sleep 1
for p in $(/system/bin/pidof pulseaudio); do kill -9 $p 2>/dev/null; done
rm -rf $XDG_RUNTIME_DIR/pulse-* $HOME/.config/pulse/*-runtime 2>/dev/null
pulseaudio --start --exit-idle-time=-1
for i in 1 2 3 4 5; do pactl info >/dev/null 2>&1 && break; sleep 1; done
pactl load-module module-native-protocol-tcp port=4713 listen=127.0.0.1 auth-anonymous=1
