#!/data/data/com.termux/files/usr/bin/sh
# Termux:Boot: audio + X server for the Debian chroot desktop (the Magisk watchdog also restarts them)
termux-wake-lock
sh $HOME/bin/zenpad-audio.sh
nohup sh $HOME/bin/zenpad-x11.sh >/dev/null 2>&1 &
