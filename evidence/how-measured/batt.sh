echo "== power_supply"; for d in /sys/class/power_supply/*; do echo "-- $(basename $d)"; cat $d/uevent 2>/dev/null | grep -vE "MODEL|MANUFACT|SERIAL" | sed 's/POWER_SUPPLY_/  /'; done
echo "== MTK battery sysfs"; B=$(ls -d /sys/devices/platform/battery* 2>/dev/null | head -1); echo "dir: $B"
for f in Charger_Type ADC_Charger_Voltage FG_Battery_CurrentConsumption Custom_Charging_Current BatteryAverageCurrent InstatVolt TemperatureR BatterySenseVoltage ISenseVoltage ChargerVoltage; do [ -r $B/$f ] && echo "  $f = $(cat $B/$f 2>/dev/null)"; done
ls $B 2>/dev/null | tr '\n' ' ' | cut -c1-900; echo
echo "== charger chip log (latest)"; dmesg | grep -E "SMB1351|smb1351|charger_type|CHR_Type|Charger Type|chr_type|BATTERY_NOTIFY" | tail -12 | cut -c1-200
echo "== cpu freq now: little $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq) big $(cat /sys/devices/system/cpu/cpu4/cpufreq/scaling_cur_freq 2>/dev/null)  online $(cat /sys/devices/system/cpu/online)"
echo "== brightness: $(cat /sys/class/leds/lcd-backlight/brightness 2>/dev/null) / $(cat /sys/class/leds/lcd-backlight/max_brightness 2>/dev/null)"
echo "== wakelocks held (top)"; cat /sys/power/wake_lock 2>/dev/null | tr ' ' '\n' | head -10 | tr '\n' ' '; echo
