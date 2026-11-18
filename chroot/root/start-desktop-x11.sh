#!/bin/bash
# LXDE on Termux:X11 (display :0). The X socket is bind-mounted into /tmp/.X11-unix by start-linux.sh.
export HOME=/root USER=root DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/xdg LANG=C.UTF-8
# Termux:X11 offers DRI3, but Mesa waits forever on its shared fences from inside the chroot -> GTK apps hang. Turn it off.
export LIBGL_DRI3_DISABLE=1
export XCURSOR_THEME=invisible XCURSOR_SIZE=32
mkdir -p /tmp/xdg && chmod 700 /tmp/xdg
for i in $(seq 1 60); do [ -S /tmp/.X11-unix/X0 ] && break; sleep 1; done
[ -S /tmp/.X11-unix/X0 ] || { echo "Termux:X11 socket X0 missing"; exit 1; }
if pgrep -x lxsession >/dev/null; then echo "desktop already up"; exit 0; fi
setsid sh -c 'export DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/xdg HOME=/root LIBGL_DRI3_DISABLE=1 XCURSOR_THEME=invisible XCURSOR_SIZE=32; dbus-launch --exit-with-session startlxde' >/root/lxde.log 2>&1 </dev/null &
sleep 5
# lxsession n'autostarte pas le panneau ici -> on le lance explicitement
setsid lxpanel --profile LXDE >/root/panel.log 2>&1 </dev/null &
setsid pcmanfm --desktop --profile LXDE >/root/pcmanfm.log 2>&1 </dev/null &
sleep 2
chroot_root_cursor=1; setsid sh -c "sleep 6; DISPLAY=:0 XCURSOR_THEME=invisible xsetroot -cursor_name left_ptr" >/dev/null 2>&1 &
echo "LXDE started on Termux:X11 (:0)"
