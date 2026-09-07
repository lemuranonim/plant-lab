[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$mobileRoot = Split-Path -Parent $PSScriptRoot
$androidSourceRoot = Join-Path $mobileRoot 'android\app\src'
$iconSizes = [ordered]@{
  mdpi = 48
  hdpi = 72
  xhdpi = 96
  xxhdpi = 144
  xxxhdpi = 192
}
$foregroundSizes = [ordered]@{
  mdpi = 108
  hdpi = 162
  xhdpi = 216
  xxhdpi = 324
  xxxhdpi = 432
}
$variants = [ordered]@{
  plant = Join-Path $mobileRoot 'assets\logo_plant.png'
  lab = Join-Path $mobileRoot 'assets\logo_lab.png'
}

function Write-ResizedPng {
  param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$DestinationPath,
    [Parameter(Mandatory = $true)][int]$Size
  )

  $destinationDirectory = Split-Path -Parent $DestinationPath
  [System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null

  $source = [System.Drawing.Image]::FromFile($SourcePath)
  $bitmap = [System.Drawing.Bitmap]::new(
    $Size,
    $Size,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
  )
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($source, 0, 0, $Size, $Size)
    $bitmap.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
    $source.Dispose()
  }
}

foreach ($variant in $variants.Keys) {
  $sourcePath = $variants[$variant]
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Flavor logo was not found: $sourcePath"
  }

  foreach ($density in $iconSizes.Keys) {
    $destination = Join-Path $androidSourceRoot "$variant\res\mipmap-$density\ic_launcher.png"
    Write-ResizedPng -SourcePath $sourcePath -DestinationPath $destination -Size $iconSizes[$density]
  }

  foreach ($density in $foregroundSizes.Keys) {
    $destination = Join-Path $androidSourceRoot "$variant\res\drawable-$density\ic_launcher_foreground.png"
    Write-ResizedPng -SourcePath $sourcePath -DestinationPath $destination -Size $foregroundSizes[$density]
  }

  Write-Output "Generated Android launcher assets for $variant."
}
