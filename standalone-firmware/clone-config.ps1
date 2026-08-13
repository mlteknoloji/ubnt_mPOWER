# Push a NetRelayMP backup JSON to many devices (fleet clone of settings).
param(
  [Parameter(Mandatory=$true)][string]$Backup,
  [string]$Target,
  [string]$TargetsFile,
  [string]$User = 'ubnt',
  [string]$Password = 'ubnt',
  [string]$Token = ''
)

$ErrorActionPreference = 'Continue'
$PSNativeCommandUseErrorActionPreference = $false
if (-not (Test-Path $Backup)) { throw "Backup not found: $Backup" }

$AskPass = Join-Path $env:TEMP 'mpower_askpass.cmd'
Set-Content -Path $AskPass -Value "@echo $Password" -Encoding ASCII
$env:SSH_ASKPASS = $AskPass
$env:SSH_ASKPASS_REQUIRE = 'force'
$env:DISPLAY = 'unused'
$SshOpts = @(
  '-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=NUL',
  '-o','HostKeyAlgorithms=+ssh-rsa','-o','PubkeyAcceptedAlgorithms=+ssh-rsa',
  '-o','KexAlgorithms=+diffie-hellman-group1-sha1','-o','Ciphers=+aes128-cbc',
  '-o','MACs=+hmac-sha1,hmac-md5','-o','PreferredAuthentications=password',
  '-o','PubkeyAuthentication=no','-o','NumberOfPasswordPrompts=1','-o','ConnectTimeout=20'
)

$hosts = @()
if ($Target) { $hosts += $Target.Trim() }
if ($TargetsFile) { $hosts += Get-Content $TargetsFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^#' } }
$hosts = $hosts | Select-Object -Unique
if (-not $hosts) { throw 'Provide -Target or -TargetsFile' }

$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Backup))

foreach ($h in $hosts) {
  Write-Host "=== Clone settings -> $h ===" -ForegroundColor Cyan
  try {
    if (-not $Token) {
      $tokOut = & ssh @SshOpts "$User@$h" "tr -d '\r\n' < /etc/persistent/mpower/api.token" 2>&1
      $Token = ($tokOut | Where-Object { $_ -match '^[0-9a-f]{32,}$' } | Select-Object -First 1)
      if (-not $Token) { throw "Could not read API token from $h" }
    }
    $url = "http://${h}:8088/cgi-bin/backup.sh?action=import&token=$Token"
    # Use curl.exe if available for binary POST; else Invoke-WebRequest
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
      $tmp = Join-Path $env:TEMP ("mpower-clone-" + $h.Replace('.', '-') + ".json")
      [System.IO.File]::WriteAllBytes($tmp, $bytes)
      & curl.exe -s -X POST --data-binary "@$tmp" $url
      Write-Host ""
    } else {
      Invoke-WebRequest -Uri $url -Method POST -Body $bytes -ContentType 'application/json' -UseBasicParsing | Select-Object -ExpandProperty Content
    }
    Write-Host "OK $h" -ForegroundColor Green
  } catch {
    Write-Host "FAIL $h : $_" -ForegroundColor Red
  }
}
