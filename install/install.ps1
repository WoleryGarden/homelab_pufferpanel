#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $PSNativeCommandUseErrorActionPreference = $true
}

$baseUrlDefault = "https://raw.githubusercontent.com/WoleryGarden/homelab_pufferpanel/main/install"
$baseUrl = if ($env:PUFFERPANEL_INSTALL_BASE_URL) { $env:PUFFERPANEL_INSTALL_BASE_URL } else { $baseUrlDefault }

$workDir = (Get-Location).Path
$traefikDir = Join-Path $workDir "traefik"
$envPath = Join-Path $workDir ".env"
$templatePath = Join-Path $workDir ".env.template"
$envHelperPath = Join-Path $workDir "envHelper.ps1"

Write-Host "Downloading installer assets from $baseUrl..."
& curl -fsSL "$baseUrl/.env.template" -o (Join-Path $workDir ".env.template")
& curl -fsSL "$baseUrl/envHelper.ps1" -o $envHelperPath

if (-not (Test-Path $envHelperPath)) {
  throw "envHelper.ps1 not found in $workDir"
}
. $envHelperPath

if (-not (Test-Path $envPath)) {
  Show-EnvHelp -envPath $envPath -templatePath $templatePath
  exit 1
}

$envVars = Read-EnvFile -envPath $envPath
Validate-Env -envVars $envVars -envPath $envPath -templatePath $templatePath

$createAdminRaw = $envVars["CREATE_ADMIN"]
$createAdmin = $false
if ($createAdminRaw) {
  $createAdmin = $createAdminRaw.ToLower() -eq "true"
}

Write-Host "Installing PufferPanel..."
curl -s https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh?any=true | sudo bash
sudo apt update
sudo apt-get install -y pufferpanel

if ($createAdmin) {
  Write-Host "Creating initial admin user (CREATE_ADMIN=True)..."
  sudo pufferpanel user add
} else {
  Write-Host "Skipping admin user creation (CREATE_ADMIN is not True)."
}

sudo usermod -aG docker pufferpanel


$configPath = "/etc/pufferpanel/config.json"

# Get docker0 IPv4
$docker0Ip = (ip -4 addr show docker0 |
  Select-String -Pattern 'inet\s+(\d+\.\d+\.\d+\.\d+)' |
  ForEach-Object { $_.Matches[0].Groups[1].Value })

if (-not $docker0Ip) { throw "Could not determine docker0 IPv4 address." }

Write-Host "Updating PufferPanel config to bind to docker0..."
$jsonText = sudo cat $configPath


$json = $jsonText | ConvertFrom-Json
$json.web.host = "$docker0Ip`:8080"


$out = $json | ConvertTo-Json -Depth 20

Write-Host "Writing updated config to $configPath..."
$out | sudo tee $configPath > $null

sudo systemctl enable --now pufferpanel

Write-Host "Installing ACL utilities..."
sudo apt install -y acl bzip2

$servers = "$($json.daemon.data.root)/servers"

Write-Host "Setting ACLs for server data at $servers..."
sudo chmod 755 $servers
sudo setfacl -R -m u:pufferpanel:rwx $servers
sudo setfacl -R -m d:u:pufferpanel:rwx $servers
sudo setfacl -R -m g:pufferpanel:rwx $servers
sudo setfacl -R -m d:g:pufferpanel:rwx $servers

Write-Host "Installing resetacl.ps1 to /usr/local/sbin..."
& sudo curl -fsSL "$baseUrl/resetacl.ps1" -o /usr/local/sbin/resetacl.ps1
& sudo chmod 755 /usr/local/sbin/resetacl.ps1

Write-Host "Installing sudoers rule..."
& sudo curl -fsSL "$baseUrl/pufferpanel-resetacl" -o /etc/sudoers.d/pufferpanel-resetacl
& sudo chmod 440 /etc/sudoers.d/pufferpanel-resetacl

Write-Host "Installing restic..."
& curl -fsSL "$baseUrl/restic-install.ps1" -o (Join-Path $workDir "restic-install.ps1")
& (Join-Path $workDir "restic-install.ps1")

Write-Host "Preparing Traefik directory..."
New-Item -ItemType Directory -Force -Path $traefikDir | Out-Null
& curl -fsSL "$baseUrl/traefik/docker-compose.yaml" -o (Join-Path $traefikDir "docker-compose.yaml")
& curl -fsSL "$baseUrl/traefik/traefik.yaml" -o (Join-Path $traefikDir "traefik.yaml")

Copy-Item -Force -Path (Join-Path $workDir ".env") -Destination (Join-Path $traefikDir ".env")

Write-Host "Starting Traefik..."
Push-Location $traefikDir
try {
  & sudo docker compose up -d --force-recreate
} finally {
  Pop-Location
}

Write-Host "Install complete."
