#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

curl -s https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh?any=true | sudo bash
sudo apt update
sudo apt-get install pufferpanel

sudo pufferpanel user add

sudo usermod -aG docker pufferpanel


$configPath = "/etc/pufferpanel/config.json"

# Get docker0 IPv4
$docker0Ip = (ip -4 addr show docker0 |
  Select-String -Pattern 'inet\s+(\d+\.\d+\.\d+\.\d+)' |
  ForEach-Object { $_.Matches[0].Groups[1].Value })

if (-not $docker0Ip) { throw "Could not determine docker0 IPv4 address." }

$jsonText = sudo cat $configPath


$json = $jsonText | ConvertFrom-Json
$json.web.host = "$docker0Ip`:8080"


$out = $json | ConvertTo-Json -Depth 20

$out | sudo tee $configPath > $null

sudo systemctl enable --now pufferpanel

sudo apt install -y acl

$servers = "$($json.daemon.data.root)/servers"

sudo chmod 755 $servers
sudo setfacl -R -m u:pufferpanel:rwx $servers
sudo setfacl -R -m d:u:pufferpanel:rwx $servers
sudo setfacl -R -m g:pufferpanel:rwx $servers
sudo setfacl -R -m d:g:pufferpanel:rwx $servers

