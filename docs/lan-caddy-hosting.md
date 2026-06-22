# LAN Caddy Hosting

The LAN hosting files run a small Caddy container that serves the local
`scripts/` directory on port `8085`.

## Start the Server

From the repository root:

```powershell
docker compose -f .\lan\docker-compose.yml up -d
```

The compose file maps host port `8085` to container port `80`, mounts
`../scripts` as read-only content, and mounts `lan/Caddyfile` as the Caddy
configuration.

## Test by IP Address

Replace `SERVER-IP` with the IP address of the machine running the container:

```powershell
irm http://SERVER-IP:8085/install.ps1 | iex
```

You can also test the non-destructive development entry point:

```powershell
irm http://SERVER-IP:8085/dev.ps1 | iex
```

## Internal DNS

Create an internal DNS record:

```text
scripts.home.arpa -> SERVER-IP
```

Then test:

```powershell
irm http://scripts.home.arpa:8085/install.ps1 | iex
```

If you want the shorter command below, map host port `80` to container port `80`
in `lan/docker-compose.yml` instead of using `8085`:

```powershell
irm http://scripts.home.arpa/install.ps1 | iex
```

Keep this service behind internal DNS and firewall rules. Do not expose the LAN
Caddy container directly to the internet.
