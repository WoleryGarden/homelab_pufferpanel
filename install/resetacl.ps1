#!/usr/bin/env pwsh

$configPath = "/etc/pufferpanel/config.json"
$jsonText = Get-Content $configPath
$json = $jsonText | ConvertFrom-Json
$servers = "$($json.daemon.data.root)/servers"

$cwd  = (Get-Location).Path

$cwdFull  = [IO.Path]::GetFullPath($cwd ).TrimEnd('/')

$underBase = ($cwdFull -eq $servers) -or $cwdFull.StartsWith("$servers/")

if ($underBase) {
  find . -type d -exec setfacl -m m:rwx '{}' ';'
  Write-Host "ACLs are reset"
} else {
  Write-Host "Cannot reset ACLs under $cwdFull"
  exit 1
}
