# mPower fleet updater (Windows)
# 1) Optional: upgrade stock Ubiquiti mFi firmware to MF.v2.1.11
# 2) Install NetRelayMP overlay
#
# Usage:
#   .\deploy.ps1 -Target 192.168.2.20
#   .\deploy.ps1 -Target 192.168.2.20 -UpgradeStock
#   .\deploy.ps1 -TargetsFile .\hosts.txt -UpgradeStock -KeepToken
#   .\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -StockBin .\firmware\MF.v2.1.11.bin

param(
  [string]$Target,
  [string]$TargetsFile,
  [string]$User = 'ubnt',
  [string]$Password = 'ubnt',
  [switch]$KeepToken,
  [switch]$UpgradeStock,
  [string]$StockBin = '',
  [string]$StockVersion = 'MF.v2.1.11',
  [switch]$ForceStockUpgrade,
  [switch]$VerifyReboot,
  [int]$RebootWaitSec = 420,
  [string]$OutCsv = ''
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Version = (Get-Content (Join-Path $Root 'VERSION') -Raw).Trim()
$AskPass = Join-Path $env:TEMP 'mpower_askpass.cmd'
Set-Content -Path $AskPass -Value "@echo $Password" -Encoding ASCII
$env:SSH_ASKPASS = $AskPass
$env:SSH_ASKPASS_REQUIRE = 'force'
$env:DISPLAY = 'unused'
# Dropbear prints host-key warnings to stderr; don't treat them as terminating errors.
$PSNativeCommandUseErrorActionPreference = $false

$StockUrls = @(
  'https://github.com/mlteknoloji/ubnt_mPOWER/raw/main/standalone-firmware/firmware/MF.v2.1.11.bin',
  'https://dl.ubnt.com/mfi/2.1.11/firmware/M2M/firmware.bin'
)
$DefaultStockBin = Join-Path $Root 'firmware\MF.v2.1.11.bin'

$SshOpts = @(
  '-o', 'StrictHostKeyChecking=no',
  '-o', 'UserKnownHostsFile=NUL',
  '-o', 'HostKeyAlgorithms=+ssh-rsa',
  '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa',
  '-o', 'KexAlgorithms=+diffie-hellman-group1-sha1',
  '-o', 'Ciphers=+aes128-cbc',
  '-o', 'MACs=+hmac-sha1,hmac-md5',
  '-o', 'PreferredAuthentications=password',
  '-o', 'PubkeyAuthentication=no',
  '-o', 'NumberOfPasswordPrompts=1',
  '-o', 'ConnectTimeout=20'
)

function Invoke-Device([string]$HostIp, [string]$RemoteCmd) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $null = & ssh @SshOpts "$User@$HostIp" $RemoteCmd 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  if ($code -ne 0) { throw "SSH failed on $HostIp (exit $code)" }
}

function Get-DeviceOutput([string]$HostIp, [string]$RemoteCmd) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $out = & ssh @SshOpts "$User@$HostIp" $RemoteCmd 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  $text = ($out | ForEach-Object { "$_" }) -join "`n"
  if ($code -ne 0) { throw "SSH failed on $HostIp (exit $code): $text" }
  return $text
}

function Test-DeviceSsh([string]$HostIp) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $null = & ssh @SshOpts "$User@$HostIp" 'echo OK' 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  return ($code -eq 0)
}

function Wait-DeviceOnline([string]$HostIp, [int]$TimeoutSec) {
  Write-Host "Waiting for $HostIp after reboot (up to ${TimeoutSec}s)..." -ForegroundColor Yellow
  Start-Sleep -Seconds 45
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if (Test-DeviceSsh $HostIp) {
      Write-Host "SSH back on $HostIp" -ForegroundColor Green
      return
    }
    Start-Sleep -Seconds 10
  }
  throw "Device $HostIp did not come back via SSH within ${TimeoutSec}s"
}

function Resolve-StockBin {
  if ($StockBin) {
    if (-not (Test-Path -LiteralPath $StockBin)) {
      throw "Stock firmware not found: $StockBin"
    }
    return (Resolve-Path -LiteralPath $StockBin).Path
  }
  if (Test-Path -LiteralPath $DefaultStockBin) {
    $local = (Resolve-Path -LiteralPath $DefaultStockBin).Path
    Write-Host "Using local stock firmware (clone): $local" -ForegroundColor Green
    return $local
  }
  $dir = Split-Path -Parent $DefaultStockBin
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $lastErr = $null
  foreach ($url in $StockUrls) {
    try {
      Write-Host "Downloading stock $StockVersion ..." -ForegroundColor Cyan
      Write-Host "  $url"
      Invoke-WebRequest -Uri $url -OutFile $DefaultStockBin -UseBasicParsing
      $len = (Get-Item -LiteralPath $DefaultStockBin).Length
      if ($len -lt 1000000) { throw "Downloaded stock bin looks too small ($len bytes)" }
      Write-Host ("Saved $len bytes -> $DefaultStockBin")
      return $DefaultStockBin
    } catch {
      $lastErr = $_
      Write-Host "Download failed from $url" -ForegroundColor Yellow
      Write-Host "  $_" -ForegroundColor Yellow
      Remove-Item -LiteralPath $DefaultStockBin -ErrorAction SilentlyContinue
    }
  }
  throw "Could not download $StockVersion. While still online, save MF.v2.1.11.bin to firmware\ then retry. Last error: $lastErr"
}

function Get-StockVersion([string]$HostIp) {
  $text = Get-DeviceOutput $HostIp "tr -d '\r\n' < /etc/version"
  $line = ($text -split "`n" | Where-Object { $_ -match 'MF\.v' } | Select-Object -First 1)
  if (-not $line) { $line = ($text -split "`n" | Select-Object -Last 1).Trim() }
  return $line.Trim()
}

function Upgrade-StockFirmware([string]$HostIp, [string]$BinPath) {
  $cur = Get-StockVersion $HostIp
  Write-Host "Stock firmware on $HostIp : $cur" -ForegroundColor Cyan
  if (-not $ForceStockUpgrade -and $cur -eq $StockVersion) {
    Write-Host "Already $StockVersion - skip stock flash" -ForegroundColor Green
    return [pscustomobject]@{ Upgraded = $false; From = $cur; To = $cur }
  }

  $size = (Get-Item -LiteralPath $BinPath).Length
  Write-Host "Flash stock $StockVersion ($size bytes) -> $HostIp" -ForegroundColor Cyan

  # Free /tmp (tmpfs ~10MB); bin is ~7.1MB
  Invoke-Device $HostIp 'rm -rf /tmp/fwupdate.bin /tmp/mpower-pkg /tmp/*.tar /tmp/*.bin 2>/dev/null; sync'

  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $null = & scp @SshOpts -O $BinPath "${User}@${HostIp}:/tmp/fwupdate.bin" 2>&1
  $scpCode = $LASTEXITCODE
  $ErrorActionPreference = $prev
  if ($scpCode -ne 0) { throw "SCP stock bin failed for $HostIp (exit $scpCode)" }

  # Validate image on device before committing flash
  $check = Get-DeviceOutput $HostIp 'ls -l /tmp/fwupdate.bin; fwupdate.real -c; echo CHECK_EXIT:$?'
  Write-Host $check
  if ($check -notmatch 'CHECK_EXIT:0') {
    throw "fwupdate.real -c rejected image on $HostIp"
  }

  Write-Host "Starting /sbin/syswrapper.sh upgrade2 (device will reboot)..." -ForegroundColor Yellow
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  # Connection usually drops mid-flash — that is expected
  $null = & ssh @SshOpts "$User@$HostIp" '/sbin/syswrapper.sh upgrade2' 2>&1
  $ErrorActionPreference = $prev

  Wait-DeviceOnline $HostIp $RebootWaitSec

  $after = Get-StockVersion $HostIp
  if ($after -ne $StockVersion) {
    throw "After flash expected $StockVersion but device reports '$after'"
  }
  Write-Host "Stock OK: $after" -ForegroundColor Green
  return [pscustomobject]@{ Upgraded = $true; From = $cur; To = $after }
}

function Deploy-Overlay([string]$HostIp) {
  Write-Host "=== Overlay $Version -> $HostIp ===" -ForegroundColor Cyan

  $stageTar = Join-Path $env:TEMP ("mpower-pkg-{0}.tar" -f $HostIp.Replace('.', '-'))
  if (Test-Path $stageTar) { Remove-Item $stageTar -Force }

  Push-Location $Root
  try {
    # BusyBox tar rejects Windows bsdtar/PAX headers; build strict classic USTAR.
    # Capture stdout so it does not leak into the function return pipeline.
    $pyExe = $null
    $pyExtraArgs = @()
    if (Get-Command python -ErrorAction SilentlyContinue) {
      $pyExe = 'python'
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
      # Windows Python Launcher
      $pyExe = 'py'
      $pyExtraArgs = @('-3')
    } else {
      throw "Python is required to build the USTAR package. Install Python or ensure the `py` launcher exists."
    }

    $packPy = Join-Path $Root 'pack-ustar.py'
    $null = & $pyExe @pyExtraArgs $packPy $Root $stageTar 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Failed to build USTAR package" }
  } finally {
    Pop-Location
  }

  # Local checksums to detect scp truncation/corruption
  $localSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $stageTar).Hash.ToLowerInvariant()
  $localMd5 = (Get-FileHash -Algorithm MD5 -LiteralPath $stageTar).Hash.ToLowerInvariant()
  $localSize = (Get-Item -LiteralPath $stageTar).Length

  # Keep a predictable copy for Settings -> Firmware update (overlay tar).
  $artifactDir = Join-Path $Root 'dist'
  New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
  $artifactVersioned = Join-Path $artifactDir ("mpower-overlay-{0}.tar" -f $Version)
  $artifactLatest = Join-Path $artifactDir 'mpower-overlay-latest.tar'
  Copy-Item -LiteralPath $stageTar -Destination $artifactVersioned -Force
  Copy-Item -LiteralPath $stageTar -Destination $artifactLatest -Force
  Write-Host "Build artifact: $artifactVersioned" -ForegroundColor Green

  Invoke-Device $HostIp 'rm -rf /tmp/mpower-pkg /tmp/mpower-seed.tar /tmp/*.tar 2>/dev/null; mkdir -p /tmp/mpower-pkg; df -h /tmp /etc/persistent 2>/dev/null || df'

  $ok = $false
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $null = & scp @SshOpts -O $stageTar "${User}@${HostIp}:/tmp/mpower-pkg/pkg.tar" 2>&1
    $scpCode = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($scpCode -ne 0) { throw "SCP failed for $HostIp (exit $scpCode)" }

    # Size + hash on device (BusyBox may only have md5sum)
    $remoteCmd = 'wc -c /tmp/mpower-pkg/pkg.tar; (sha256sum /tmp/mpower-pkg/pkg.tar 2>/dev/null || md5sum /tmp/mpower-pkg/pkg.tar 2>/dev/null)'
    $remoteText = Get-DeviceOutput $HostIp $remoteCmd
    $remoteSize = ([regex]::Match($remoteText, '(\d+)\s+/tmp/mpower-pkg/pkg\.tar')).Groups[1].Value
    $remoteHash = ([regex]::Match($remoteText, '([0-9a-fA-F]{32,64})\s')).Groups[1].Value.ToLowerInvariant()

    if (-not $remoteSize -or [int64]$remoteSize -ne $localSize) {
      Write-Host ("Tar size mismatch attempt={0} local={1} remote={2}" -f $attempt, $localSize, $remoteSize) -ForegroundColor Yellow
      continue
    }
    if (-not $remoteHash) {
      Write-Host ("Remote hash missing attempt={0}" -f $attempt) -ForegroundColor Yellow
      continue
    }
    if ($remoteHash.Length -eq 64) {
      if ($remoteHash -ne $localSha) {
        Write-Host ("Tar sha256 mismatch attempt={0}" -f $attempt) -ForegroundColor Yellow
        continue
      }
    } elseif ($remoteHash -ne $localMd5) {
      Write-Host ("Tar md5 mismatch attempt={0} local={1} remote={2}" -f $attempt, $localMd5, $remoteHash) -ForegroundColor Yellow
      continue
    }

    Write-Host ("Tar OK size={0} hash={1}..." -f $localSize, $remoteHash.Substring(0, [Math]::Min(12, $remoteHash.Length))) -ForegroundColor Green
    $ok = $true
    break
  }
  if (-not $ok) {
    throw "Tar transfer failed after retries (size/hash mismatch) on $HostIp"
  }

  # Extract then install; keep tar warnings visible but do not treat them alone as fatal
  # BusyBox ash rejects `set -e` if install.sh still has Windows CRLF.
  $installCmd = 'cd /tmp/mpower-pkg && tar xf pkg.tar; echo TAR_EXIT:$?; tr -d ''\r'' < install.sh > install.lf && mv install.lf install.sh; chmod +x install.sh && sh ./install.sh'
  if (-not $KeepToken) {
    $installCmd = 'rm -f /etc/persistent/mpower/api.token; ' + $installCmd
  }

  $ErrorActionPreference = 'Continue'
  $out = & ssh @SshOpts "$User@$HostIp" $installCmd 2>&1
  $sshCode = $LASTEXITCODE
  $ErrorActionPreference = $prev
  $text = ($out | ForEach-Object { "$_" }) -join "`n"
  Write-Host $text

  if ($sshCode -ne 0 -or $text -notmatch 'Flash persistence: OK' -or $text -notmatch 'OK installed') {
    throw "Install/flash persistence did not report OK on $HostIp (exit $sshCode)"
  }

  $token = ([regex]::Match($text, 'TOKEN=([0-9a-f]+)').Groups[1].Value)
  $ui = ([regex]::Match($text, 'UI=(http://\S+)').Groups[1].Value)
  if (-not $ui) { $ui = "http://${HostIp}:8088" }

  if ($VerifyReboot) {
    # Optional cold-start persistence verification.
    Write-Host "Verifying persistence with a real reboot..." -ForegroundColor Yellow
    $ErrorActionPreference = 'Continue'
    $null = & ssh @SshOpts "$User@$HostIp" 'sync; reboot' 2>&1
    $ErrorActionPreference = $prev
    Wait-DeviceOnline $HostIp $RebootWaitSec

    $verifyCmd = "v=`$(cat /etc/persistent/mpower/.installed 2>/dev/null); " +
      "test x`"`$v`" = x'$Version' && " +
      "test -x /etc/persistent/mpower/bin/mpower-service.sh && " +
      "test -x /etc/persistent/rc.poststart && " +
      "echo PERSIST_OK:`$v || { echo PERSIST_FAIL:`$v; exit 1; }"
    $verify = Get-DeviceOutput $HostIp $verifyCmd
    Write-Host $verify
    if ($verify -notmatch ("PERSIST_OK:" + [regex]::Escape($Version))) {
      throw "Overlay did not survive reboot on $HostIp; cfg MTD is damaged or too small"
    }
  }

  return [pscustomobject]@{
    Host = $HostIp
    Stock = ''
    Overlay = $Version
    UI = $ui
    Token = $token
    Status = $(if ($VerifyReboot) { 'OK (reboot verified)' } else { 'OK' })
  }
}

function Deploy-One([string]$HostIp, [string]$BinPath) {
  $stockInfo = $null
  if ($UpgradeStock) {
    $stockInfo = Upgrade-StockFirmware $HostIp $BinPath
  }

  # Take last object in case any stdout leaked from Deploy-Overlay
  $row = Deploy-Overlay $HostIp | Select-Object -Last 1
  if (-not ($row -is [psobject]) -or -not ($row.PSObject.Properties.Name -contains 'Host')) {
    throw "Deploy-Overlay returned unexpected object: $($row.GetType().FullName)"
  }
  if (-not ($row.PSObject.Properties.Name -contains 'Stock')) {
    $row | Add-Member -NotePropertyName Stock -NotePropertyValue '' -Force
  }

  if ($stockInfo) {
    if ($stockInfo.Upgraded) {
      $row.Stock = ("{0} -> {1}" -f $stockInfo.From, $stockInfo.To)
    } else {
      $row.Stock = ("skip ({0})" -f $stockInfo.To)
    }
  } else {
    try { $row.Stock = Get-StockVersion $HostIp } catch { $row.Stock = '?' }
  }
  return $row
}

$hosts = @()
if ($Target) { $hosts += $Target.Trim() }
if ($TargetsFile) {
  $hosts += Get-Content $TargetsFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^#' }
}
$hosts = $hosts | Select-Object -Unique
if (-not $hosts) {
  Write-Host "Usage: .\deploy.ps1 -Target 192.168.2.20"
  Write-Host "       .\deploy.ps1 -Target 192.168.2.20 -UpgradeStock"
  Write-Host "       .\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -StockBin .\firmware\MF.v2.1.11.bin -KeepToken"
  Write-Host "       .\deploy.ps1 -TargetsFile .\hosts.txt -UpgradeStock -KeepToken"
  exit 1
}

$binPath = $null
if ($UpgradeStock) {
  $binPath = Resolve-StockBin
}

$results = @()
foreach ($h in $hosts) {
  try {
    $results += Deploy-One $h $binPath
  } catch {
    Write-Host "FAIL $h : $_" -ForegroundColor Red
    $results += [pscustomobject]@{
      Host = $h
      Stock = ''
      Overlay = $Version
      UI = ''
      Token = ''
      Status = "FAIL: $_"
    }
  }
}

$results | Format-Table -AutoSize
if (-not $OutCsv) {
  $OutCsv = Join-Path $Root ("deploy-results-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$results | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $OutCsv
Write-Host "CSV: $OutCsv"
