#!/data/data/com.termux/files/usr/bin/sh
# Termux:X11 server :0. Socket lives in $HOME/.x11tmp (Termux wipes $PREFIX/tmp on restart).
# OLD_CONTEXT=1 is required on Android 7 (see termux-x11-patch/README.md on the PC).
termux-wake-lock
export TMPDIR=$HOME/.x11tmp
mkdir -p $TMPDIR/.X11-unix
# already running (Termux:Boot and the watchdog can both call this at boot) -> leave it alone
if /system/bin/ps | grep -q "termux-x11 com.termux.x11 :0"; then exit 0; fi
rm -f $TMPDIR/.X11-unix/X0 $TMPDIR/.X0-lock
OLD_CONTEXT=1 exec termux-x11 :0 -ac > $HOME/termux-x11.log 2>&1
