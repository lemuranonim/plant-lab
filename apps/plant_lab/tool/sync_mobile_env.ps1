[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$mobileRoot = Split-Path -Parent $PSScriptRoot
$adminEnvPath = Join-Path $mobileRoot '..\admin\.env.local'
$mobileEnvPath = Join-Path $mobileRoot '.env'

if (-not (Test-Path -LiteralPath $adminEnvPath)) {
  throw "Local environment file was not found: $adminEnvPath"
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
if (-not $publishableKey.StartsWith('sb_publishable_')) {
  throw 'Plant/Lab mobile requires a modern sb_publishable_ client key.'
}

$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
$mobileEnvLines = @(
  "SUPABASE_URL=$supabaseUrl"
  "SUPABASE_PUBLISHABLE_KEY=$publishableKey"
)
[System.IO.File]::WriteAllLines($mobileEnvPath, $mobileEnvLines, $utf8WithoutBom)

Write-Output 'Plant/Lab mobile .env synchronized (values hidden).'
