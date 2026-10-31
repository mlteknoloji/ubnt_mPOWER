# Diagnose a device after "cfgmtd flash write failed".
# Default: read-only facts (RAM, flash partitions, /etc sizes) + make sure the
# NetRelayMP services run. -RetryFlash also frees RAM and retries cfgmtd once.
# Output: recover-result-<time>.txt next to deploy.ps1.
# With -RetryFlash: do NOT reboot the device unless it reports CFGMTD_EXIT:0.
#
#   .\tools\device-recover.ps1 -Target 192.168.1.132
param(
  [string]$Target = '192.168.1.132',
  [string]$User = 'ubnt',
  [string]$Password = 'ubnt',
  [switch]$RetryFlash,
  [switch]$MeasureOnly,  # only a clean 120 s performance sample + top
  [switch]$ButtonInfo,   # read-only: who respawns wevent / mca-monitor, and how often
  [switch]$ChurnInfo,    # read-only: 60 s of PID churn for hostapd/mcad/wpa/udhcpc + AP logs
  [switch]$BootInfo      # read-only: boot timeline after a reboot (run within ~10 min of boot)
)

$ErrorActionPreference = 'Continue'
$PSNativeCommandUseErrorActionPreference = $false
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Out = Join-Path $Root ("recover-result-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

$AskPass = Join-Path $env:TEMP 'mpower_askpass.cmd'
Set-Content -Path $AskPass -Value "@echo $Password" -Encoding ASCII
$env:SSH_ASKPASS = $AskPass
$env:SSH_ASKPASS_REQUIRE = 'force'
$env:DISPLAY = 'unused'
$SshOpts = @(
  '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL',
  '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa',
  '-o', 'KexAlgorithms=+diffie-hellman-group1-sha1', '-o', 'Ciphers=+aes128-cbc',
  '-o', 'MACs=+hmac-sha1,hmac-md5', '-o', 'PreferredAuthentications=password',
  '-o', 'PubkeyAuthentication=no', '-o', 'NumberOfPasswordPrompts=1',
  '-o', 'ConnectTimeout=20'
)

$cmd = @'
echo == facts; cat /etc/persistent/mpower/.installed; cut -d. -f1 /proc/uptime
echo == free before; free
echo == df; df
echo == /proc/mtd; cat /proc/mtd
echo == persistent size; du -s /etc/persistent /etc/persistent/* 2>/dev/null; tar cf - -C /etc persistent 2>/dev/null | gzip -c | wc -c
echo == gz bytes per persistent dir
for d in /etc/persistent/*; do printf '%s ' $d; tar cf - $d 2>/dev/null | gzip -c | wc -c; done
echo == stock dirs; ls -la /etc/persistent/data /etc/persistent/cfg /etc/persistent/log /etc/persistent/bin 2>/dev/null | head -80
echo == mtd errors; dmesg | grep -i -e mtd -e flash -e ecc -e erase | tail -10
echo == etc sizes; ls -la /etc/persistent; du -s /etc/* 2>/dev/null | sort -n | tail -10
echo == /tmp big files; du -s /tmp/* 2>/dev/null | sort -n | tail -8
echo == processes; ps w | wc -l; ps w | grep -c mpower/
__RETRY__
echo == services
# Start only when the UI is really down: `start` also relaunches time-sync and
# wifi-client, which re-associates Wi-Fi and skews the measurement below.
ps w | grep -q 'httpd -p 80[8]8' || /etc/persistent/mpower/bin/mpower-service.sh start >/tmp/mpower-standalone.log 2>&1
sleep 3; ps w | grep -e 'mpower/' -e 'httpd -p 80[8]8'
echo == dmesg tail; dmesg | tail -15
echo == measure 60s; [ -f /etc/persistent/mpower/bin/measure.sh ] && sh /etc/persistent/mpower/bin/measure.sh 60 diag
'@ -replace "`r", ''
$retry = ''
if ($RetryFlash) {
  $retry = "echo == free RAM, retry flash write`nrm -rf /tmp/mpower-pkg /tmp/*.tar 2>/dev/null; sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null`nfree`ncfgmtd -w -p /etc; echo CFGMTD_EXIT:`$?"
}
$cmd = $cmd.Replace('__RETRY__', $retry)

if ($ButtonInfo) {
  $Out = $Out -replace 'recover-result-', 'button-result-'
  $cmd = @'
echo == facts; cat /etc/persistent/mpower/.installed; cut -d. -f1 /proc/uptime
echo == inittab; ls -la /etc/inittab; cat /etc/inittab
echo == etc mount; mount | grep -e ' / ' -e ' /etc' -e tmpfs
echo == wevent binaries; ls -la /usr/bin/wevent /bin/wevent /bin/mca-monitor 2>&1
echo == button log; grep -c respawned /tmp/mpower-button.log; tail -n 12 /tmp/mpower-button.log
echo == pid churn 30s
i=0; while [ $i -lt 6 ]; do echo $(cut -d. -f1 /proc/uptime) wevent=$(pidof wevent) mca-monitor=$(pidof mca-monitor) mcad=$(pidof mcad); sleep 5; i=$((i+1)); done
echo == parents; for p in $(pidof wevent mca-monitor mcad); do printf '%s ppid=' $p; cut -d' ' -f4 /proc/$p/stat; done
'@ -replace "`r", ''
}

if ($ChurnInfo) {
  $Out = $Out -replace 'recover-result-', 'churn-result-'
  $cmd = @'
echo == facts; cat /etc/persistent/mpower/.installed; cut -d. -f1 /proc/uptime
echo == ap state; cat /tmp/mpower-ap.state; for i in ath1 ath2; do printf '%s flags=' $i; cat /sys/class/net/$i/flags 2>/dev/null || echo none; done
echo == pid churn 60s
i=0; while [ $i -lt 12 ]; do echo $(cut -d. -f1 /proc/uptime) hostapd=$(pidof hostapd) mcad=$(pidof mcad) wpa=$(pidof wpa_supplicant) udhcpc=$(pidof udhcpc) ath1=$(cat /sys/class/net/ath1/flags 2>/dev/null); sleep 5; i=$((i+1)); done
echo == ap log; tail -n 15 /tmp/mpower-ap.log
echo == watchdog log; tail -n 15 /tmp/mpower-watchdog.log
echo == syslog hostapd mcad; grep -e hostapd -e mcad /var/log/messages 2>/dev/null | tail -n 15
'@ -replace "`r", ''
}

if ($BootInfo) {
  $Out = $Out -replace 'recover-result-', 'boot-result-'
  $cmd = @'
echo == facts; cat /etc/persistent/mpower/.installed; cut -d. -f1 /proc/uptime
echo == boot timeline - seconds since power-on; cat /tmp/mpower-boot-timeline.log
echo == pwdog in inittab; grep -c pwdog /etc/inittab; ps w | grep -c '[p]wdog'
echo == wifi result; cat /tmp/mpower-wifi-result
echo == frozen; for p in $(pidof wevent hostapd); do printf '%s ' $p; cut -d' ' -f2,3 /proc/$p/stat; done
'@ -replace "`r", ''
}

if ($MeasureOnly) {
  # Clean performance sample: nothing heavy runs before or during it.
  $Out = $Out -replace 'recover-result-', 'measure-result-'
  $cmd = @'
echo == facts; cat /etc/persistent/mpower/.installed; cut -d. -f1 /proc/uptime
echo == settle 20s; sleep 20
echo == top before; top -b -n1 2>/dev/null | head -22
n0=$(grep -c 'init: starting pid' /var/log/messages 2>/dev/null)
echo == measure 120s; sh /etc/persistent/mpower/bin/measure.sh 120 clean
echo == top after; top -b -n1 2>/dev/null | head -22
echo == init respawns during the 120s window
grep 'init: starting pid' /var/log/messages 2>/dev/null | tail -n +$((${n0:-0} + 1)) | sed 's/.*: .\(.*\).$/\1/' | sort | uniq -c
'@ -replace "`r", ''
}

Write-Host "Connecting to $Target ..." -ForegroundColor Cyan
Set-Content -Path $Out -Value "=== device-recover $Target $(Get-Date)"
Write-Host "Writing to $Out (lines are saved as they arrive)"
# Each line is appended immediately, so an interrupted run still leaves data.
# The script goes over stdin: the device's old dropbear rejects exec commands
# longer than ~1024 chars ("exec request failed on channel 0"). PowerShell
# pipes CRLF, so the device strips CR before handing the text to sh.
$OutputEncoding = New-Object System.Text.UTF8Encoding $false   # no BOM in front of the script
# tr also drops a UTF-8 BOM (EF BB BF) PowerShell may prepend; the script is pure ASCII.
$cmd | & ssh @SshOpts "$User@$Target" "tr -d '\015\357\273\277' | sh" 2>&1 | ForEach-Object { "$_" } |
  Where-Object { $_ -notmatch '^Warning: Permanently added' } |
  ForEach-Object { Write-Host $_; Add-Content -Path $Out -Value $_ }
Add-Content -Path $Out -Value "ssh exit=$LASTEXITCODE"
try {
  $s = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 "http://${Target}:8088/cgi-bin/status.sh"
  Add-Content -Path $Out -Value ("status.sh: " + $s.Content)
  Write-Host "UI :8088 is back" -ForegroundColor Green
} catch { Add-Content -Path $Out -Value "status.sh failed: $_"; Write-Host "UI :8088 still down" -ForegroundColor Red }
Write-Host "Saved: $Out"
