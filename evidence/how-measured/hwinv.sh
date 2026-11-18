#!/system/bin/sh
BB=/data/adb/magisk/busybox
echo "== version"; cat /proc/version
echo "== cmdline"; cat /proc/cmdline; echo
echo "== props"; for p in ro.product.model ro.product.device ro.board.platform ro.hardware ro.build.fingerprint ro.bootloader ro.boot.hardware ro.mediatek.platform ro.boot.serialno ro.product.cpu.abi; do echo "$p=$(getprop $p)"; done
echo "== dt model/compatible"; cat /proc/device-tree/model 2>/dev/null; echo; cat /proc/device-tree/compatible 2>/dev/null | tr '\0' ' '; echo
echo "== fdt"; ls -l /sys/firmware/fdt 2>&1; ls -ld /proc/device-tree /sys/firmware/devicetree/base 2>&1
echo "== by-name"; ls -l /dev/block/platform/mtk-msdc.0/11230000.MSDC0/by-name/ | $BB awk '{print $(NF-2), $NF}'
echo "== /proc/partitions"; cat /proc/partitions
echo "== mmc hosts"; for d in /sys/class/mmc_host/*; do echo "$(basename $d): $(ls $d | grep mmc | tr '\n' ' ')"; for c in $d/mmc*:*; do [ -d "$c" ] && echo "   $(basename $c) type=$(cat $c/type 2>/dev/null) name=$(cat $c/name 2>/dev/null) vendor=$(cat $c/vendor 2>/dev/null) device=$(cat $c/device 2>/dev/null)"; done; done
echo "== i2c"; for d in /sys/bus/i2c/devices/*; do n=$(cat $d/name 2>/dev/null); dr=$(readlink $d/driver 2>/dev/null); echo "$(basename $d): name=$n driver=${dr##*/} of=$(cat $d/of_node/compatible 2>/dev/null | tr '\0' ' ')"; done
echo "== spi"; ls /sys/bus/spi/devices/ 2>&1
echo "== input"; cat /proc/bus/input/devices | grep -E "^N:|^H:|^P:"
echo "== asound"; cat /proc/asound/cards; cat /proc/asound/pcm 2>/dev/null | head -20
echo "== power_supply"; for d in /sys/class/power_supply/*; do echo "$(basename $d): type=$(cat $d/type 2>/dev/null) cap=$(cat $d/capacity 2>/dev/null) tech=$(cat $d/technology 2>/dev/null)"; done
echo "== net"; ls /sys/class/net; for n in /sys/class/net/*; do echo "$(basename $n) -> $(readlink $n/device 2>/dev/null) drv=$(readlink $n/device/driver 2>/dev/null)"; done
echo "== modules"; cat /proc/modules
echo "== cpu"; cat /sys/devices/system/cpu/possible; for c in 0 4; do echo "cpu$c part: $(grep -m1 'CPU part' /proc/cpuinfo)"; done; grep -E "Hardware|CPU part" /proc/cpuinfo | sort | uniq -c
echo "== mem"; head -2 /proc/meminfo
echo "== usb"; for d in /sys/bus/usb/devices/*; do [ -f $d/idVendor ] && echo "$(basename $d) $(cat $d/idVendor):$(cat $d/idProduct) $(cat $d/product 2>/dev/null)"; done; ls /sys/class/udc/ 2>&1
echo "== typec/extcon"; ls /sys/class/typec /sys/class/extcon /sys/class/dual_role_usb 2>&1
echo "== drm/fb"; ls /sys/class/drm /sys/class/graphics 2>&1; cat /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/name 2>/dev/null
echo "== gpu"; ls -d /sys/devices/platform/*gpu* /sys/devices/platform/*mfg* /dev/pvr* /dev/dri 2>&1 | head
echo "== thermal"; for t in /sys/class/thermal/thermal_zone*; do echo "$(basename $t): $(cat $t/type)"; done
echo "== dmesg hw grep"; dmesg | grep -i -E "lcm|panel|touch|tpd|wlan|wifi|mt6630|wmt|pvr|rogue|rt5659|codec|charger|bq2|fuel|gauge|ps8640|anx|edp|dsi|mipi|it6151|tc358|sensor|accel|als|hall|fusb|ptn5150|tusb|typec|type-c|tfa|speaker|amp" | head -100
