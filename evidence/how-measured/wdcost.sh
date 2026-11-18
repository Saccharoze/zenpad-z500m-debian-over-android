#!/system/bin/sh
BB=/data/adb/magisk/busybox; W=$(cat /data/local/tmp/zenpad-watchdog.pid)
s() { $BB awk '{print $14+$15+$16+$17}' /proc/$1/stat; }
a=$(s $W); sleep 60; b=$(s $W)
echo "watchdog $W: $((b-a)) ticks in 60s = $(( (b-a)*100/6000 ))% of one core"
echo "log tail:"; tail -3 /data/local/tmp/zenpad-watchdog.log
