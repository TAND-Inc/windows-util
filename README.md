# Windows Script Distribution

This repository is a simple distribution point for Windows-focused PowerShell
scripts. It supports two intended entry points:

- Public shortcuts served from the Cloudflare Worker Custom Domain
  `get.tand.us`.
- LAN-only shortcuts served from an internal Caddy container for private network
  use.

The repo also keeps the existing Windows setup toolkit launcher and example
scripts, so future install/dev/uninstall entry points can grow without changing
the hosting model.

## Public Usage

Use the public route only after you control and trust the domain and the script
it serves:

```powershell
irm https://get.tand.us/launcher | iex
irm https://get.tand.us/install | iex
irm https://get.tand.us/dev | iex
```

The Cloudflare Worker in `worker/cloudflare-worker.js` maps friendly routes such
as `/install` and `/dev` to raw PowerShell files in this GitHub repository.
`wrangler.toml` points Cloudflare's Git-backed build at that Worker entrypoint
and configures the `get.tand.us` Worker Custom Domain.

Cloudflare deployment and domain attachment are manual unless you configure
Wrangler authentication. Test the returned script before executing it:

```powershell
irm https://get.tand.us/install
```

## LAN-Aware Launcher

The main public launcher command is:

```powershell
irm https://get.tand.us/launcher | iex
```

The launcher works from anywhere. When it runs from inside the LAN, it probes:

```text
http://scripts.home.arpa:8085/lan-manifest.json
```

If that LAN manifest responds with the expected `TAND-LAN-LAUNCHER-v1` marker,
the launcher shows a LAN Tools menu. Outside the LAN, or when internal DNS is
unavailable, LAN Tools are hidden.

Menu hiding is not a security boundary. LAN-only scripts must still be protected
by the LAN Caddy server and firewall rules.

Test commands:

```powershell
irm https://get.tand.us/launcher | iex
irm http://scripts.home.arpa:8085/lan-manifest.json
irm http://scripts.home.arpa:8085/lan/lan-diagnostics.ps1 | iex
```

## LAN Usage

The LAN Caddy container serves the files from `scripts/` directly and also
serves LAN-only files from `lan/`:

```powershell
irm http://scripts.home.arpa/install.ps1 | iex
```

If you keep the sample Docker port mapping, include the port when testing:

```powershell
irm http://scripts.home.arpa:8085/install.ps1 | iex
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
|-- wrangler.toml
|-- README.md
|-- launcher.ps1
|-- config/
|   `-- apps.json
|-- docs/
|   |-- conventions.md
|   |-- lan-caddy-hosting.md
|   |-- public-cloudflare-worker.md
|   `-- security-notes.md
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
`-- lan/
    |-- Caddyfile
    |-- docker-compose.yml
    |-- lan-manifest.json
    `-- lan-diagnostics.ps1
```
