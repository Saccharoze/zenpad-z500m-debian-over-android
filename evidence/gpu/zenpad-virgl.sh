#!/data/data/com.termux/files/usr/bin/sh
# GPU bridge: Linux apps (GALLIUM_DRIVER=virpipe) -> Android's PowerVR GLES driver.
# Socket in the dir the chroot already sees as /tmp/.X11-unix
S=$HOME/.x11tmp/.X11-unix/.virgl_test
if /system/bin/ps | grep -q virgl_test_server; then exit 0; fi
rm -f $S
exec virgl_test_server_android --multi-clients --socket-path $S ${VIRGL_MODE} > $HOME/virgl.log 2>&1
