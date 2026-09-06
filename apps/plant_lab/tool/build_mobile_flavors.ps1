[CmdletBinding()]
param(
  [ValidateSet('debug', 'release')]
  [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'
$launcherPath = Join-Path $PSScriptRoot 'flutter_with_local_config.ps1'
$command = if ($Mode -eq 'debug') {
  'build-apk-debug'
} else {
  'build-apk-release'
}

foreach ($flavor in @('plant', 'lab')) {
  Write-Output "Building $flavor APK ($Mode)..."
  & $launcherPath -Command $command -Flavor $flavor
}
