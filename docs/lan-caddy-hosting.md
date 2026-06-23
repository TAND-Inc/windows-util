# LAN Caddy Hosting

The LAN hosting files run a small Caddy container on port `8085`. It serves the
local `scripts/` directory for shared script entry points and the local `lan/`
directory for LAN-only manifest and tools.

## Start the Server

From the repository root:

```powershell
docker compose -f .\lan\docker-compose.yml up -d
```

The compose file maps host port `8085` to container port `80`, mounts
`../scripts` as read-only script content, mounts the compose directory itself as
read-only LAN-only content, and generates `/etc/caddy/Caddyfile` inside the
container at startup.

Portainer had trouble with file-to-file Caddyfile bind mounts, so this stack
does not mount `./Caddyfile` or the `lan/` directory to `/etc/caddy`. The
checked-in `lan/Caddyfile` remains a readable reference, while
`lan/docker-compose.yml` writes the runtime Caddyfile with a shell heredoc and
then runs:

```text
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
```

When deploying through Portainer, set the Compose path to:

```text
lan/docker-compose.yml
```

Because that compose file lives inside `lan/`, relative bind mounts are resolved
from the `lan/` directory. In this stack, `./` means the repo's `lan/` folder,
not the repository root.

## Test by IP Address

Replace `SERVER-IP` with the IP address of the machine running the container:

```powershell
irm http://SERVER-IP:8085/install.ps1 | iex
```

You can also test the non-destructive development entry point:

```powershell
irm http://SERVER-IP:8085/dev.ps1 | iex
```

Test the LAN-aware launcher manifest and placeholder LAN diagnostics:

```powershell
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

If you want the shorter command below, map host port `80` to container port `80`
in `lan/docker-compose.yml` instead of using `8085`:

```powershell
irm http://scripts.home.arpa/install.ps1 | iex
```

Keep this service behind internal DNS and firewall rules. Do not expose the LAN
Caddy container directly to the internet.
