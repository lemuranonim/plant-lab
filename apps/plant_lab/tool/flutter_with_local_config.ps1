[CmdletBinding()]
param(
  [ValidateSet('run', 'build-apk-debug', 'build-apk-release')]
  [string]$Command = 'run',
  [Parameter(Mandatory = $true)]
  [ValidateSet('plant', 'lab')]
  [string]$Flavor,
  [string]$DeviceId = ''
)

$ErrorActionPreference = 'Stop'

$mobileRoot = Split-Path -Parent $PSScriptRoot
$flutterPath = 'D:\flutter\bin\flutter.bat'
$syncScriptPath = Join-Path $PSScriptRoot 'sync_mobile_env.ps1'

if (-not (Test-Path -LiteralPath $flutterPath)) {
  throw "Flutter executable was not found: $flutterPath"
}
if (-not (Test-Path -LiteralPath $syncScriptPath)) {
  throw "Mobile environment sync script was not found: $syncScriptPath"
}

& $syncScriptPath

$configurationArgs = @(
  '--flavor'
  $Flavor
  '--target'
  "lib/main_$Flavor.dart"
  '--dart-define=OPERATIONAL_WRITES_ENABLED=false'
)

$flutterArgs = switch ($Command) {
  'run' {
    $runArgs = @('run')
    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
      $runArgs += @('--device-id', $DeviceId)
    }
    $runArgs
  }
  'build-apk-debug' { @('build', 'apk', '--debug') }
  'build-apk-release' { @('build', 'apk', '--release') }
}

Push-Location $mobileRoot
try {
  & $flutterPath @flutterArgs @configurationArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter exited with code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
