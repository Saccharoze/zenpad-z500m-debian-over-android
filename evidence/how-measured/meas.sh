BB=/data/adb/magisk/busybox; R=/data/local/linux; T=/data/local/tmp/meas; rm -rf $T; mkdir -p $T
snap() { $BB awk '{l=$0; r=0; for(k=length(l);k>0;k--) if(substr(l,k,1)==")"){r=k;break}; n=split(substr(l,r+2),f," "); print substr(l,1,index(l," ")-1), f[12]+f[13]+f[14]+f[15]}' /proc/[0-9]*/stat 2>/dev/null; }
snap > $T/c0; head -1 /proc/stat > $T/s0; sleep 20; snap > $T/c1; head -1 /proc/stat > $T/s1
# classify every current process
for d in /proc/[0-9]*; do p=${d#/proc/}; cmd=$(tr '\0' ' ' < $d/cmdline 2>/dev/null); [ -z "$cmd" ] && { echo "$p kernel kthread:$(cat $d/comm 2>/dev/null)"; continue; }
  root=$(readlink $d/root 2>/dev/null); uid=$($BB awk '/^Uid:/{print $2}' $d/status 2>/dev/null); nm=$(echo "$cmd" | cut -c1-40 | tr ' ' '_')
  if [ "$root" = "$R" ]; then case "$cmd" in *firefox-esr*) g=linux-firefox;; *) g=linux-desktop;; esac
  else case "$cmd" in pulseaudio*|termux-x11*|com.termux*|*virgl*) g=bridge-termux;; *zenpad-desktop*|magisk*) g=magisk-watchdog;; *) [ "${uid:-0}" -ge 10000 ] && { [ "$uid" = 10113 ] && g=bridge-termux || g=android-apps; } || g=android-system;; esac; fi
  echo "$p $g $nm"; done > $T/cls
$BB awk '/^Pss:/{s[FILENAME]+=$2} END{for(f in s){split(f,a,"/"); print a[3], s[f]}}' /proc/[0-9]*/smaps 2>/dev/null > $T/pss
$BB ls -l /proc/[0-9]*/fd 2>/dev/null | $BB awk '/^\/proc\/[0-9]+\/fd:/{split($0,a,"/"); pid=a[3]} /\/dev\/(dri|pvr|ged|mali)/{n[pid]++} END{for(p in n) print p, n[p]}' > $T/gpu
$BB awk -v T=$T 'BEGIN{while((getline l < (T"/c0"))>0){split(l,a," "); c0[a[1]]=a[2]} while((getline l < (T"/c1"))>0){split(l,a," "); c1[a[1]]=a[2]} while((getline l < (T"/pss"))>0){split(l,a," "); ps[a[1]]=a[2]} while((getline l < (T"/gpu"))>0){split(l,a," "); gp[a[1]]=1}}
 {p=$1; g=$2; nm=$3; cpu=(p in c0 && p in c1)? c1[p]-c0[p] : 0; if(cpu<0)cpu=0; G[g]+=cpu; M[g]+=ps[p]; if(p in gp) U[g]=U[g]" "nm; print cpu, ps[p]+0, g, nm > (T"/proc")}
 END{print "GROUP            RAM(MB)  CPU(% of 1 core)  GPU users"; for(g in M) printf "%-16s %7.0f  %8.1f          %s\n", g, M[g]/1024, G[g]/20, substr(U[g],1,90)}' $T/cls
$BB awk '{split($0,a," "); t=0; for(i=2;i<=8;i++) t+=a[i]; print t, a[5]}' $T/s0 $T/s1 | $BB awk 'NR==1{t0=$1;i0=$2} NR==2{printf "TOTAL CPU busy: %.0f%% of all 6 cores\n", 100-($2-i0)*100/($1-t0)}'
echo "== top 8 by RAM (MB)"; sort -k2 -n -r $T/proc | head -8 | $BB awk '{printf "  %6.0f  %-14s %s\n", $2/1024, $3, $4}'
echo "== top 8 by CPU (% of 1 core)"; sort -k1 -n -r $T/proc | head -8 | $BB awk '{printf "  %6.1f  %-14s %s\n", $1/20, $3, $4}'
echo "== memory"; grep -E "^(MemTotal|MemFree|MemAvailable|Cached|SwapTotal|SwapFree):" /proc/meminfo | tr -s ' ' | tr '\n' ' '; echo
echo "== cpu online: $(cat /sys/devices/system/cpu/online)  freq little(cpu0): $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)  big(cpu4): $(cat /sys/devices/system/cpu/cpu4/cpufreq/scaling_cur_freq 2>/dev/null)"
echo "== GPU counters"; for f in /d/ged/hal/gpu_utilization /d/ged/hal/current_freqency /proc/gpufreq/gpufreq_var_dump /proc/gpufreq/gpufreq_opp_freq /sys/kernel/debug/ged/hal/gpu_utilization; do [ -r $f ] && { echo "-- $f"; head -c 400 $f; echo; }; done 2>/dev/null
rm -rf $T
