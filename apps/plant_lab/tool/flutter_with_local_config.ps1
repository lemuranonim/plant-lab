[CmdletBinding()]
param(
  [ValidateSet('run', 'build-apk-debug', 'build-apk-release')]
  [string]$Command = 'run',
  [string]$DeviceId = ''
)

$ErrorActionPreference = 'Stop'

$mobileRoot = Split-Path -Parent $PSScriptRoot
$adminEnvPath = Join-Path $mobileRoot '..\admin\.env.local'
$flutterPath = 'D:\flutter\bin\flutter.bat'

if (-not (Test-Path -LiteralPath $adminEnvPath)) {
  throw "Local environment file was not found: $adminEnvPath"
}
if (-not (Test-Path -LiteralPath $flutterPath)) {
  throw "Flutter executable was not found: $flutterPath"
}

$localConfig = @{}
foreach ($line in Get-Content -LiteralPath $adminEnvPath) {
  if ($line -match '^\s*([^#][^=]+)=(.*)$') {
    $name = $matches[1].Trim()
    $value = $matches[2].Trim().Trim('"').Trim("'")
    $localConfig[$name] = $value
  }
}

$supabaseUrl = $localConfig['NEXT_PUBLIC_SUPABASE_URL']
$publishableKey = $localConfig['NEXT_PUBLIC_SUPABASE_ANON_KEY']
if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or
    [string]::IsNullOrWhiteSpace($publishableKey)) {
  throw 'NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY is missing from apps/admin/.env.local.'
}

$configurationArgs = @(
  "--dart-define=SUPABASE_URL=$supabaseUrl"
  "--dart-define=SUPABASE_PUBLISHABLE_KEY=$publishableKey"
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
