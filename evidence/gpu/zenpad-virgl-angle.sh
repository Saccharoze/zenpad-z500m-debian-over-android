#!/data/data/com.termux/files/usr/bin/sh
for p in $(/system/bin/pidof virgl_test_server_android); do kill $p; done; sleep 1
S=$HOME/.x11tmp/.X11-unix/.virgl_test; rm -f $S
exec virgl_test_server_android --multi-clients --angle-gl --socket-path $S > $HOME/virgl.log 2>&1
