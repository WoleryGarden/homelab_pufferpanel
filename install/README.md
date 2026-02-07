# PufferPanel Install

This installer sets up PufferPanel plus Traefik with Let's Encrypt DNS-01 (Cloudflare).

Prereqs:
- Debian host
- `docker`, `curl`, `git`, and `pwsh` already installed
- Run as `root` or with passwordless `sudo`

## Setup

1. Create a working directory and enter it.
2. Create `.env` from the template and fill it out.

```bash
curl -fsSL https://raw.githubusercontent.com/WoleryGarden/homelab_pufferpanel/main/install/.env.template -o .env.template
cp .env.template .env
```

Edit `.env` with your values:
- `DOMAIN`: the public domain for PufferPanel (Traefik will request a cert for this)
- `LE_EMAIL`: email used for Let's Encrypt registration
- `CF_DNS_API_TOKEN`: Cloudflare API token with DNS edit permissions
- `CREATE_ADMIN`: `True` to run `sudo pufferpanel user add`, otherwise `False`

3. Run the one-liner from the same directory that contains your `.env`.

```bash
curl -fsSL https://raw.githubusercontent.com/WoleryGarden/homelab_pufferpanel/main/install/install.ps1 -o /tmp/pufferpanel-install.ps1 && pwsh -NoProfile -File /tmp/pufferpanel-install.ps1
```

## What It Does

The install script will:
- Download `envHelper.ps1`
- Validate `.env` and install PufferPanel
- Update `/etc/pufferpanel/config.json` to bind to `docker0`
- Install ACL utilities and set server ACLs
- Install `resetacl.ps1` to `/usr/local/sbin`
- Install the sudoers rule under `/etc/sudoers.d`
- Create a `traefik/` directory and download `docker-compose.yaml` + `traefik.yaml`
- Start Traefik (`docker compose up -d --force-recreate`)
