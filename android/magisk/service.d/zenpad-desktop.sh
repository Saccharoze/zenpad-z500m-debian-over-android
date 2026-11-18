#!/system/bin/sh
# Magisk boot service + watchdog: Debian chroot desktop on Termux:X11.
# Pause it:  touch /data/local/tmp/zenpad-watchdog.off
# single instance: exit if another watchdog is alive
PIDF=/data/local/tmp/zenpad-watchdog.pid
if [ -f $PIDF ] && [ -d /proc/$(cat $PIDF) ] && grep -q zenpad-desktop /proc/$(cat $PIDF)/cmdline 2>/dev/null; then exit 0; fi
echo $$ > $PIDF
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 3; done
LOG=/data/local/tmp/zenpad-watchdog.log
H=/data/data/com.termux/files/home
TX=$H/.x11tmp/.X11-unix
ROOT=/data/local/linux
log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> $LOG; }
rc() { am startservice --user 0 -n com.termux/com.termux.app.RunCommandService -a com.termux.RUN_COMMAND \
        --es com.termux.RUN_COMMAND_PATH /data/data/com.termux/files/usr/bin/sh --esa com.termux.RUN_COMMAND_ARGUMENTS "$1" \
        --ez com.termux.RUN_COMMAND_BACKGROUND true >/dev/null 2>&1; }
xalive() { for p in /proc/[0-9]*; do case "$(cat $p/cmdline 2>/dev/null | tr '\0' ' ')" in "termux-x11 com.termux.x11 :0"*) return 0;; esac; done; return 1; }
palive() { grep -qE ":1269 [0-9A-F]+:0000 0A" /proc/net/tcp /proc/net/tcp6 2>/dev/null; }
# keep Android's low-memory killer away from the pieces the Linux desktop needs (Android may reset the app values; re-applied every loop)
protect() { for p in /proc/[0-9]*; do case "$(cat $p/cmdline 2>/dev/null | tr '\0' ' ')" in "termux-x11 com.termux.x11 :0"*|"pulseaudio "*|"com.termux "*|"com.termux.x11 "*) echo -800 > $p/oom_score_adj 2>/dev/null;; esac; done; }
dalive() { for p in /proc/[0-9]*; do [ "$(cat $p/comm 2>/dev/null)" = lxsession ] && return 0; done; return 1; }
# PulseAudio can stay "up" (TCP port open) while its Android OpenSL output is stalled: every stream then freezes,
# and Firefox/YouTube video waits forever on the audio clock ("If playback doesn't begin shortly...").
# Probe: play 0.3 s of silence through the chroot's client (same path as Firefox). Healthy: ~0.4 s. Stalled: never
# drains -> timeout. Returns 0 (true) when STUCK. Skipped until the chroot's /dev is mounted.
pastuck() {
  grep -q " $ROOT/dev " /proc/mounts || return 1
  /data/adb/magisk/busybox chroot $ROOT /usr/bin/env -i HOME=/root PATH=/usr/bin:/bin LANG=C.UTF-8 \
    sh -c 'head -c 52920 /dev/zero | timeout 10 pacat --raw --format=s16le --rate=44100 --channels=2' >/dev/null 2>&1 && return 1
  return 0
}
pa_n=0; pa_fail=0
[ $(wc -c < $LOG 2>/dev/null || echo 0) -gt 200000 ] && mv $LOG $LOG.old
log "boot"
# responsiveness tuning (runtime only; thermal limits untouched). Defaults: go_hispeed_load 99, hispeed 1703000, target_loads 90, hps up 80 / down 70 / down_times 10, scheduler cfq
tune() {
  I=/sys/devices/system/cpu/cpu0/cpufreq/interactive
  echo 85 > $I/go_hispeed_load; echo 1300000 > $I/hispeed_freq; echo 80 > $I/target_loads
  echo 65 > /proc/hps/up_threshold; echo 50 > /proc/hps/down_threshold; echo 20 > /proc/hps/down_times
  echo deadline > /sys/block/mmcblk0/queue/scheduler
  log "tuned: hispeed_load=$(cat $I/go_hispeed_load) target=$(cat $I/target_loads) hps=$(cat /proc/hps/up_threshold)/$(cat /proc/hps/down_threshold) io=$(cat /sys/block/mmcblk0/queue/scheduler)"
}
[ -e /data/local/tmp/zenpad-tune.off ] || tune
sleep 12
# give Termux:Boot up to 45 s to start the X server itself (avoids two servers racing)
for i in $(seq 1 45); do xalive && break; sleep 1; done
while true; do
  if [ ! -e /data/local/tmp/zenpad-watchdog.off ]; then
    # ASUS Mobile Manager may re-block auto-start
    for p in com.termux com.termux.boot com.termux.x11; do appops set $p AUTO_RUN allow 2>/dev/null; done
    palive || { log "audio down -> start"; rc $H/bin/zenpad-audio.sh; }
    # every ~60 s: is the audio output stalled? 2 failed probes in a row -> kill PulseAudio; palive restarts it next round.
    # (A Firefox that was playing during the stall may stay frozen: restart Firefox if YouTube still won't play.)
    if palive; then
      pa_n=$((pa_n+1))
      if [ $((pa_n % 3)) -eq 0 ]; then
        if pastuck; then pa_fail=$((pa_fail+1)); log "audio probe failed ($pa_fail/2)"; else pa_fail=0; fi
        if [ $pa_fail -ge 2 ]; then log "audio stalled -> restarting PulseAudio"; kill -9 $(pidof pulseaudio) 2>/dev/null; pa_fail=0; fi
      fi
    fi
    if ! xalive; then
      log "X server down -> start"
      for n in lxsession lxpanel pcmanfm openbox pasystray; do pkill -x $n; done
      rc $H/bin/zenpad-x11.sh
      for i in $(seq 1 20); do [ -S $TX/X0 ] && break; sleep 1; done
    fi
    if [ -S $TX/X0 ]; then
      # share the X socket dir with the chroot (re-mount if stale)
      if ! grep -q " $ROOT/tmp/.X11-unix " /proc/mounts || grep -q "$ROOT/tmp/.X11-unix\\\\040(deleted)" /proc/mounts; then
        umount $ROOT/tmp/.X11-unix 2>/dev/null; mkdir -p $ROOT/tmp/.X11-unix
        /data/adb/magisk/busybox mount --bind $TX $ROOT/tmp/.X11-unix && log "socket dir mounted"
      fi
      if ! dalive; then
        log "desktop down -> start"
        sh /data/local/tmp/start-linux.sh >> $LOG 2>&1
      fi
    fi
  fi
  protect
  sleep 20
done
