#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $PSNativeCommandUseErrorActionPreference = $true
}

$archSuffix = "amd64"

Write-Host "Fetching latest restic release info..."
$releaseJson = & curl -fsSL https://api.github.com/repos/restic/restic/releases/latest
if ($LASTEXITCODE -ne 0) { throw "Failed to fetch restic release info." }

$release = $releaseJson | ConvertFrom-Json
$tag = $release.tag_name
if (-not $tag) { throw "Could not determine restic release tag." }

$version = $tag.TrimStart("v")
$assetName = "restic_${version}_linux_${archSuffix}.bz2"
$downloadUrl = "https://github.com/restic/restic/releases/download/$tag/$assetName"

$installDir = "/opt/restic/$version"
$binPath = "$installDir/restic"
$linkPath = "/usr/local/bin/restic"

if (Test-Path $binPath) {
  Write-Host "restic $version already installed at $binPath."
} else {
  $tmpDir = "/tmp/restic-$version"
  if (Test-Path $tmpDir) {
    Remove-Item -Recurse -Force $tmpDir
  }
  New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

  $archivePath = Join-Path $tmpDir $assetName
  Write-Host "Downloading $assetName..."
  & curl -fsSL $downloadUrl -o $archivePath
  if ($LASTEXITCODE -ne 0) { throw "Failed to download restic archive." }

  Write-Host "Extracting..."
  & bunzip2 -f $archivePath
  if ($LASTEXITCODE -ne 0) { throw "Failed to extract restic archive." }

  $extractedPath = Join-Path $tmpDir ("restic_${version}_linux_${archSuffix}")
  if (-not (Test-Path $extractedPath)) {
    throw "Extracted restic binary not found."
  }

  Write-Host "Installing to $binPath..."
  & sudo mkdir -p $installDir
  & sudo mv $extractedPath $binPath
  & sudo chmod 755 $binPath

  Remove-Item -Recurse -Force $tmpDir
}

Write-Host "Updating symlink at $linkPath..."
& sudo ln -sfn $binPath $linkPath

Write-Host "restic $version installed."
