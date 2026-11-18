#!/system/bin/sh
BB=/data/adb/magisk/busybox; R=/data/local/linux
X() { $BB chroot $R /usr/bin/env -i HOME=/root USER=root PATH=/usr/bin:/bin LANG=C.UTF-8 "$@"; }
echo "== sinks"; X pactl list sinks 2>&1 | grep -E "Name:|State:|Latency|Mute|Volume: front" | head -8
echo "== sink-inputs (who is playing)"; X pactl list sink-inputs 2>&1 | grep -E "Sink Input|Corked|application.name|media.name|Latency|Buffer|Sink:" | head -20
echo "== 1.5 s tone test (should take ~1.5 s if audio flows)"; 
X sh -c 'head -c 264600 /dev/zero > /tmp/silence.raw; t0=$(date +%s.%N); timeout 15 pacat --raw --format=s16le --rate=44100 --channels=2 /tmp/silence.raw; rc=$?; t1=$(date +%s.%N); echo "pacat rc=$rc took $(echo "$t1 - $t0" | bc) s"; rm -f /tmp/silence.raw'
echo "== times: android $(date '+%H:%M') / chroot $(X date '+%H:%M %Z')  tz=$(getprop persist.sys.timezone)"
