#!/system/bin/sh
# Mounts + starts LXDE in the Debian chroot on Termux:X11 :0 (socket dir is bind-mounted by the watchdog).
BB=/data/adb/magisk/busybox
ROOT=/data/local/linux
D1=$(getprop net.dns1); D2=$(getprop net.dns2)
rm -f "$ROOT/etc/resolv.conf"
{ [ -n "$D1" ] && echo "nameserver $D1"; [ -n "$D2" ] && echo "nameserver $D2"; echo "nameserver 8.8.8.8"; echo "options single-request-reopen"; } > "$ROOT/etc/resolv.conf"
grep -q " $ROOT/dev " /proc/mounts || $BB mount --bind /dev "$ROOT/dev"
grep -q " $ROOT/proc " /proc/mounts || $BB mount -t proc proc "$ROOT/proc"
grep -q " $ROOT/sys " /proc/mounts || $BB mount -t sysfs sys "$ROOT/sys"
mkdir -p "$ROOT/dev/pts"; grep -q " $ROOT/dev/pts " /proc/mounts || $BB mount -t devpts devpts "$ROOT/dev/pts"
cp /data/local/tmp/start-desktop-x11.sh "$ROOT/root/start-desktop-x11.sh"; chmod 755 "$ROOT/root/start-desktop-x11.sh"
$BB chroot "$ROOT" /usr/bin/env -i HOME=/root USER=root TERM=xterm PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 /bin/bash /root/start-desktop-x11.sh
am start -n com.termux.x11/.MainActivity >/dev/null 2>&1
