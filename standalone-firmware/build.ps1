param(
  [string]$OutputDir = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Version = (Get-Content (Join-Path $Root 'VERSION') -Raw).Trim()
if (-not $OutputDir) { $OutputDir = Join-Path $Root 'dist' }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path
$VersionedTar = Join-Path $OutputDir ("mpower-overlay-{0}.tar" -f $Version)
$LatestTar = Join-Path $OutputDir 'mpower-overlay-latest.tar'

$pyExe = $null
$pyExtraArgs = @()
if (Get-Command python -ErrorAction SilentlyContinue) {
  $pyExe = 'python'
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
  $pyExe = 'py'
  $pyExtraArgs = @('-3')
} else {
  throw 'Python is required to build the BusyBox-compatible USTAR package.'
}

Push-Location $Root
try {
  $packPy = Join-Path $Root 'pack-ustar.py'
  & $pyExe @pyExtraArgs $packPy $Root $VersionedTar
  if ($LASTEXITCODE -ne 0) { throw 'Failed to build or verify USTAR package.' }
} finally {
  Pop-Location
}

Copy-Item -LiteralPath $VersionedTar -Destination $LatestTar -Force
$size = (Get-Item -LiteralPath $VersionedTar).Length
$sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $VersionedTar).Hash.ToLowerInvariant()
Write-Host "Overlay package ready" -ForegroundColor Green
Write-Host "  $VersionedTar"
Write-Host "  $LatestTar"
Write-Host "  size=$size sha256=$sha"

[pscustomobject]@{
  Version = $Version
  Package = $VersionedTar
  Latest = $LatestTar
  Size = $size
  SHA256 = $sha
}
