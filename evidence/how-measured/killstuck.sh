#!/system/bin/sh
BB=/data/adb/magisk/busybox
c512=$(cat /proc/512/cmdline 2>/dev/null | tr '\0' ' ')
c1481=$(cat /proc/1481/cmdline 2>/dev/null | tr '\0' ' '); pp1481=$(cut -d' ' -f4 /proc/1481/stat 2>/dev/null)
echo "512: '$c512'   1481: '$c1481' (parent $pp1481)"
case "$c512" in "sh /data/local/tmp/ytfix.sh"*) ;; *) echo "ABORT: 512 is not ytfix.sh"; exit 1;; esac
case "$c1481" in "tr"*) [ "$pp1481" = 512 ] || { echo "ABORT: 1481 parent is not 512"; exit 1; } ;; *) echo "ABORT: 1481 is not tr"; exit 1;; esac
kill -TERM 512 1481; sleep 2
for p in 512 1481; do [ -d /proc/$p ] && { echo "$p still alive -> SIGKILL"; kill -KILL $p; }; done; sleep 1
for p in 512 1481; do [ -d /proc/$p ] && echo "$p STILL ALIVE" || echo "$p gone"; done
a1=$($BB awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8}' /proc/stat); i1=$($BB awk '/^cpu /{print $5}' /proc/stat)
sleep 20
a2=$($BB awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8}' /proc/stat); i2=$($BB awk '/^cpu /{print $5}' /proc/stat)
echo "whole tablet busy now: $(( 100 - (i2-i1)*100/(a2-a1) ))% of all 6 cores (was 24%)"
echo "loadavg: $(cat /proc/loadavg)"
