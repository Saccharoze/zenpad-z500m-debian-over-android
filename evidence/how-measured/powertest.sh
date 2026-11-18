#!/system/bin/sh
R=/data/local/linux; OUT=/data/local/tmp/power.out; RAW=/data/local/tmp/power.raw; : > $OUT; : > $RAW
F=/sys/devices/mediatek,battery_meter; C=/sys/devices/mediatek,battery_common
log() { echo "$*" >> $OUT; }
status() { cat /sys/class/power_supply/battery/status; }
sample() { echo "$1 $(date +%s) $(cat $F/FG_Current_mA) $(cat $F/FG_g_fg_dbg_bat_current) $(cat $C/FG_Battery_CurrentConsumption) $(cat $F/FG_g_fg_dbg_bat_volt) $(cat /sys/class/leds/lcd-backlight/brightness 2>/dev/null) $(cat /sys/class/power_supply/battery/capacity) $(cat /sys/class/thermal/thermal_zone0/temp)" >> $RAW; }
phase() { # phase NAME SECONDS
  n=0; while [ $n -lt $2 ]; do sample $1; sleep 2; n=$((n+2)); done
  # averages of the 3 current columns (skip first 10 s of each phase)
  grep "^$1 " $RAW | tail -n +6 | while read p t a b c v bl cap tmp; do echo "$a $b $c $v $bl $cap $tmp"; done > /data/local/tmp/ph.txt
  k=0; sa=0; sb=0; sc=0; sv=0; while read a b c v bl cap tmp; do k=$((k+1)); sa=$((sa+a)); sb=$((sb+b)); sc=$((sc+c)); sv=$((sv+v)); BL=$bl; CAP=$cap; TMP=$tmp; done < /data/local/tmp/ph.txt
  [ $k -gt 0 ] && log "$1: FG_Current_mA=$((sa/k)) dbg_bat_current=$((sb/k)) CurrentConsumption=$((sc/k)) volt=$((sv/k))mV backlight=$BL battery=$CAP% temp=$TMP (n=$k)"; }
ENV="HOME=/root PATH=/usr/bin:/bin DISPLAY=:0 XDG_RUNTIME_DIR=/tmp/xdg LIBGL_DRI3_DISABLE=1 MOZ_CRASHREPORTER_DISABLE=1"
ffpids() { for p in /proc/[0-9]*; do case "$(tr '\0' ' ' < $p/cmdline 2>/dev/null)" in firefox-esr\ *--profile\ /tmp/ff-*|/usr/lib/firefox-esr/*) echo ${p#/proc/};; esac; done; }
killff() { for p in $(ffpids); do kill -9 $p 2>/dev/null; done; sleep 2; }
ff() { killff; rm -rf $R/tmp/ff-pw; cp -a $R/tmp/ff-template $R/tmp/ff-pw; chroot $R /usr/bin/env -i $ENV firefox-esr --no-remote --profile /tmp/ff-pw "$1" >/dev/null 2>&1 & }
log "waiting for unplug..."; while [ "$(status)" != "Discharging" ]; do sleep 2; done; log "unplugged at $(date +%H:%M:%S), battery $(cat /sys/class/power_supply/battery/capacity)%"
sleep 10
phase idle_desktop 90
ff "file:///root/autoscroll.html"; sleep 40
chroot $R /usr/bin/env -i $ENV sh -c 'W=$(xdotool search --name autoscroll | head -1); xdotool windowactivate $W; xdotool mousemove 400 300' 2>/dev/null
( for i in 1 2 3; do chroot $R /usr/bin/env -i $ENV xdotool key s 2>/dev/null; sleep 21; done ) &
phase browsing_scroll 60
ff "file:///root/video.html"; sleep 25
phase video_720p 60
killff; sleep 5
input keyevent KEYCODE_POWER; sleep 20
phase screen_off_standby 240
input keyevent KEYCODE_WAKEUP
log "done at $(date +%H:%M:%S), battery $(cat /sys/class/power_supply/battery/capacity)%"
