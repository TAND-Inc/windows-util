# Windows Script Distribution

This repository is a simple distribution point for Windows-focused PowerShell
scripts. It supports two intended entry points:

- Public shortcuts served from the Cloudflare Worker Custom Domain
  `get.tand.us`.
- LAN-only shortcuts served from an internal Caddy container for private network
  use.

The primary launcher experience is the WPF Windows Setup Toolkit. The same WPF
engine runs in WAN mode with a public-safe manifest and in LAN mode with a
private manifest served from the LAN script server.

## Public Usage

Use the public route only after you control and trust the domain and the script
it serves:

```powershell
irm https://get.tand.us/launcher | iex
```

`/launcher` opens the WPF GUI in WAN mode. The WAN manifest is
`config/wan-apps.json`, served through the Cloudflare Worker. Public-safe script
items resolve relative to `https://get.tand.us`.

`wrangler.toml` points Cloudflare's Git-backed build at that Worker entrypoint
and configures the `get.tand.us` Worker Custom Domain.

Cloudflare deployment and domain attachment are manual unless you configure
Wrangler authentication. Test the returned script before executing it:

```powershell
irm https://get.tand.us/install
```

## WPF WAN/LAN Launcher

WAN/Public GUI:

```powershell
irm https://get.tand.us/launcher | iex
```

LAN/Private GUI:

```powershell
irm https://get.home.us/launcher | iex
```

Temporary LAN testing alternatives:

```powershell
irm http://get.home.us:8085/launcher | iex
irm http://scripts.home.arpa:8085/launcher | iex
irm http://SERVER-IP:8085/launcher | iex
```

The WPF footer includes `Switch to LAN` in WAN mode and `Switch to WAN` in LAN
mode. The switch uses the same shared engine and reloads the correct manifest.

The legacy console launcher remains available as a fallback at:

```powershell
irm https://get.tand.us/console | iex
```

Menu hiding is not a security boundary. LAN-only scripts must still be protected
by the LAN Caddy server and firewall rules.

## LAN Launcher Export

The LAN GUI must work even when the LAN has no access to Cloudflare or GitHub.
Export the public-safe WPF engine and LAN bootstrapper to the private
NAS/Caddy folder:

```powershell
.\tools\export-lan-launcher.ps1 -DestinationPath \\NAS\WindowsUtilScripts -LanBaseUrl https://get.home.us
```

For temporary IP testing, export with the test base URL:

```powershell
.\tools\export-lan-launcher.ps1 -DestinationPath \\NAS\WindowsUtilScripts -LanBaseUrl http://SERVER-IP:8085 -Force
```

The helper writes `launcher`, `launcher.ps1`, and `lib/wpf-menu-engine.ps1`. It
does not copy private scripts or credentials. Create your private
`lan-manifest.json`, `scripts/`, and `installers/` in the destination folder.

## LAN Usage

The LAN version is intended for internal network use only. This GitHub repo
contains deployment scaffolding, docs, and safe examples. The actual LAN scripts
live outside GitHub on a NAS-mounted or private Docker host folder.

Portainer deploys this repo as a Git Repository stack. The Caddy container
mounts the private script folder read-only and serves that folder to RFC1918 LAN
clients. No private LAN scripts are committed to GitHub, and the container should
not be exposed directly to the internet.

For Portainer, use:

```text
Deployment method: Git Repository
Repository URL: this repo
Compose path: docker-compose.yml
```

Set these Portainer environment variables:

```text
LAN_SCRIPT_SOURCE=/mnt/windows-util-scripts
LAN_SCRIPT_PORT=8085
```

`LAN_SCRIPT_SOURCE` must be an absolute path on the Docker host. It should point
to a NAS-mounted or private local folder that already exists.

Test from a LAN Windows workstation:

```powershell
irm http://SERVER-IP:8085/install.ps1
irm http://SERVER-IP:8085/install.ps1 | iex
irm http://SERVER-IP:8085/dev.ps1 | iex
irm http://SERVER-IP:8085/uninstall.ps1 | iex
irm http://SERVER-IP:8085/launcher | iex
irm http://SERVER-IP:8085/lan-manifest.json
irm http://SERVER-IP:8085/scripts/lan-diagnostics.ps1 | iex
```

With internal DNS:

```text
scripts.home.arpa -> SERVER-IP
```

Then:

```powershell
irm http://scripts.home.arpa:8085/install.ps1 | iex
irm http://scripts.home.arpa:8085/launcher | iex
```

Example private folder structure:

```text
/mnt/windows-util-scripts/
|-- launcher
|-- launcher.ps1
|-- install.ps1
|-- dev.ps1
|-- uninstall.ps1
|-- lan-manifest.json
|-- lib/
|   `-- wpf-menu-engine.ps1
|-- scripts/
|   `-- lan-diagnostics.ps1
`-- installers/
```

## Recommended Release Workflow

For public commands, prefer Git tags or GitHub releases instead of pointing users
at `main`.

1. Review and test the scripts locally.
2. Commit the changes.
3. Create a version tag, for example `v0.1.0`.
4. Update the Worker raw URL to point at that tag.
5. Deploy the Worker.

Pinned tags make the public shortcut stable. A future push to `main` will not
silently change what users receive until you intentionally update the Worker.

## Security Notes

`irm <url> | iex` downloads code and immediately executes it. Use this pattern
only with domains and scripts you control and trust. Prefer HTTPS for public
scripts, review changes before tagging releases, and consider code signing later
if this becomes a broader distribution channel.

This repository intentionally contains no secrets. Do not commit API tokens,
passwords, private URLs, certificates, or environment-specific credentials.

More detail is in:

- `docs/public-cloudflare-worker.md`
- `docs/lan-aware-launcher.md`
- `docs/lan-caddy-hosting.md`
- `docs/security-notes.md`

## Project Layout

```text
.
|-- docker-compose.yml
|-- .dockerignore
|-- .env.example
|-- wrangler.toml
|-- README.md
|-- launcher.ps1
|-- lib/
|   `-- wpf-menu-engine.ps1
|-- config/
|   |-- apps.json
|   `-- wan-apps.json
|-- docs/
|   |-- lan-aware-launcher.md
|   |-- conventions.md
|   |-- lan-caddy-hosting.md
|   |-- public-cloudflare-worker.md
|   `-- security-notes.md
|-- examples/
|   `-- private-script-source/
|-- scripts/
|   |-- install.ps1
|   |-- launcher.ps1
|   |-- dev.ps1
|   |-- uninstall.ps1
|   |-- lib/
|   |   `-- common.ps1
|   `-- *.ps1
|-- worker/
|   `-- cloudflare-worker.js
|-- tools/
|   `-- export-lan-launcher.ps1
`-- lan/
    |-- Caddyfile
```
