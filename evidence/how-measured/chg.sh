for d in ac usb battery; do echo "$d: $(cat /sys/class/power_supply/$d/uevent 2>/dev/null | grep -E 'ONLINE|STATUS|CAPACITY=|VOLTAGE_NOW' | sed 's/POWER_SUPPLY_//' | tr '\n' ' ')"; done
echo "== charger detection / setup (latest)"; dmesg | grep -E "Set Charging Current Done|same charger|setting .*mA charging|Setting input current limit|AICL|ASUS adapter|adapter detect|TypeC|Type C|PD |HVDCP|QC" | tail -10 | sed -E 's/^\[ *[0-9.]+\] +\([0-9]\)\[[0-9]+:[a-zA-Z_]+\]//' | cut -c1-170
echo "== battery current (last 5 readings, negative = draining)"; dmesg | grep -oE "BatCur:-?[0-9]+mA" | tail -5 | tr '\n' ' '; echo
echo "== input limit lines"; dmesg | grep -E "Input current limit is|AC input current limit" | tail -2 | sed -E 's/^.*SMB1351 //'
