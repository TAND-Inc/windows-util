# LAN Caddy Hosting

The LAN hosting stack runs a small custom Caddy image on port `8085` by default.
It serves public script entry points from `scripts/` and LAN-only manifest/tools
from `lan/`.

The supported Portainer deployment now builds the image from this Git repository
instead of bind-mounting repository files into the container. During image build:

- `scripts/` is copied into `/srv/scripts/`.
- `lan/` is copied into `/srv/lan/`.
- `lan/Caddyfile` is copied into `/etc/caddy/Caddyfile`.

No host bind mounts are used for `/srv/scripts`, `/srv/lan`, or `/etc/caddy`.
This avoids Portainer relative path handling and file-vs-directory bind mount
issues.

## Portainer Deployment

Create a Portainer Git Repository stack with:

```text
Repository URL: <this repository URL>
Compose path: docker-compose.yml
```

The root `docker-compose.yml` builds the image with:

```text
context: .
dockerfile: lan/Dockerfile
```

The default published port is `8085`. To change it, set:

```text
LAN_SCRIPT_PORT=<port>
```

Do not use `lan/docker-compose.yml`; that older bind-mount stack has been
removed.

## Local Docker Test

From the repository root:

```powershell
docker compose up -d --build
```

## Test by IP Address

Replace `SERVER-IP` with the IP address of the machine running the container:

```powershell
irm http://SERVER-IP:8085/install.ps1
irm http://SERVER-IP:8085/install.ps1 | iex
irm http://SERVER-IP:8085/dev.ps1 | iex
irm http://SERVER-IP:8085/uninstall.ps1 | iex
irm http://SERVER-IP:8085/lan-manifest.json
irm http://SERVER-IP:8085/lan/lan-diagnostics.ps1 | iex
```

## Internal DNS

Create an internal DNS record:

```text
scripts.home.arpa -> SERVER-IP
```

Then test:

```powershell
irm http://scripts.home.arpa:8085/install.ps1 | iex
irm http://scripts.home.arpa:8085/lan-manifest.json
irm http://scripts.home.arpa:8085/lan/lan-diagnostics.ps1 | iex
```

Keep this service behind internal DNS and firewall rules. Do not expose the LAN
Caddy container directly to the internet.
