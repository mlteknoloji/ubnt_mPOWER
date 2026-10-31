# Before/after performance test on one device.
# 1) baseline measurement with the overlay currently installed
# 2) build + deploy this working copy (-KeepToken)
# 3) wait for things to settle, measure again, collect health checks
# Writes everything to perf-result-<time>.txt next to deploy.ps1.
#
#   .\tools\perf-test.ps1 -Target 192.168.1.132
param(
  [string]$Target = '192.168.1.132',
  [string]$User = 'ubnt',
  [string]$Password = 'ubnt',
  [int]$Seconds = 120,
  [int]$SettleSec = 180
)

$ErrorActionPreference = 'Continue'
$PSNativeCommandUseErrorActionPreference = $false
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Out = Join-Path $Root ("perf-result-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

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

function Note([string]$t) { Write-Host $t -ForegroundColor Cyan; Add-Content -Path $Out -Value $t }
function Dev([string]$cmd) {
  $o = & ssh @SshOpts "$User@$Target" $cmd 2>&1 | ForEach-Object { "$_" } |
    Where-Object { $_ -notmatch '^Warning: Permanently added' }
  $o | ForEach-Object { Write-Host $_ }
  Add-Content -Path $Out -Value ($o -join "`n")
}

$State = 'echo "overlay=$(cat /etc/persistent/mpower/.installed) uptime=$(cut -d. -f1 /proc/uptime)"; ' +
  'echo "mqtt.conf: $(grep ^enabled= /etc/persistent/mpower/mqtt.conf 2>/dev/null)"; ' +
  'echo "ping.conf: $(grep ^enabled /etc/persistent/mpower/ping.conf 2>/dev/null | tr ''\n'' '' '')"; ' +
  'echo "mqtt status: $(cat /tmp/mpower-mqtt-status.json 2>/dev/null)"'

Note "=== perf-test $Target  $(Get-Date)"
Note "--- BEFORE: state"
Dev $State

Note "--- BEFORE: measure ${Seconds}s (keep the web UI closed)"
& scp @SshOpts -O (Join-Path $Root 'payload\mpower\bin\measure.sh') "${User}@${Target}:/tmp/measure.sh" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Note "scp failed (exit $LASTEXITCODE) - check password / reachability"; exit 1 }
Dev "sh /tmp/measure.sh $Seconds once"

Note "--- DEPLOY"
& (Join-Path $Root 'deploy.ps1') -Target $Target -User $User -Password $Password -KeepToken *>&1 |
  ForEach-Object { "$_" } | Tee-Object -Variable dep | Out-Null
Add-Content -Path $Out -Value ($dep -join "`n")
if (($dep -join "`n") -notmatch 'OK installed') { Note "DEPLOY FAILED - see log above"; exit 1 }

Note "--- settle ${SettleSec}s"
Start-Sleep -Seconds $SettleSec

Note "--- AFTER: state"
Dev $State
Note "--- AFTER: measure ${Seconds}s"
Dev "sh /etc/persistent/mpower/bin/measure.sh $Seconds sonra"

Note "--- AFTER: health"
Dev 'tail -n 15 /tmp/mpower-watchdog.log; echo ...; tail -n 8 /tmp/mpower-mqtt.log; echo ...; tail -n 8 /tmp/mpower-pingwatch.log 2>/dev/null; echo ...; ls -la /tmp/mpower-static.cache 2>/dev/null; cat /tmp/mpower-measure.log'
try {
  $s = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 "http://${Target}:8088/cgi-bin/status.sh"
  Note ("status.sh: " + $s.Content)
} catch { Note "status.sh request failed: $_" }

Note "=== done -> $Out"
