# WPF WAN/LAN Launcher

The public WAN launcher is:

```powershell
irm https://get.tand.us/launcher | iex
```

The private LAN launcher is:

```powershell
irm https://get.home.us/launcher | iex
```

Temporary LAN test forms are also supported when the exported bootstrap was
generated with the matching base URL:

```powershell
irm http://get.home.us:8085/launcher | iex
irm http://scripts.home.arpa:8085/launcher | iex
irm http://SERVER-IP:8085/launcher | iex
```

## Shared WPF Engine

`lib/wpf-menu-engine.ps1` renders the same WPF GUI in both modes:

- Categories
- Checkboxes
- Installed/applied status where possible
- Select All
- Clear
- Recommended
- Switch to LAN/WAN
- Close
- Run Selected

WAN mode loads `config/wan-apps.json` from `https://get.tand.us`. LAN mode loads
`/lan-manifest.json` from the LAN base URL.

## Mode Switching

In WAN mode, the footer button says `Switch to LAN`. The engine tries:

1. `-LanBaseUrl` or an existing LAN mode base URL.
2. `TAND_LAN_BASE_URL`.
3. `%APPDATA%\TAND\WindowsUtil\config.json`.
4. Default internal DNS candidates:
   - `https://get.home.us`
   - `http://get.home.us:8085`
   - `http://scripts.home.arpa:8085`
   - `http://windows-util-scripts.home.arpa:8085`

Each candidate is tested with `GET /lan-manifest.json`. Private IP addresses are
not hardcoded as defaults in this public repo.

In LAN mode, the footer button says `Switch to WAN`. Switching to WAN loads the
public manifest from `https://get.tand.us`. If WAN is unreachable, the engine
shows a friendly message and stays in LAN mode.

## Manual LAN URL

If auto-detection fails, enter the LAN base URL manually:

```text
http://SERVER-IP:8085
```

The engine validates:

```text
http://SERVER-IP:8085/lan-manifest.json
```

The working URL can be saved for the current user:

```text
%APPDATA%\TAND\WindowsUtil\config.json
```

Example saved config:

```json
{
  "LanBaseUrl": "http://SERVER-IP:8085"
}
```

## Environment Override

Set a persistent user environment variable:

```powershell
[Environment]::SetEnvironmentVariable("TAND_LAN_BASE_URL", "http://SERVER-IP:8085", "User")
```

For the current PowerShell session only:

```powershell
$env:TAND_LAN_BASE_URL = "http://SERVER-IP:8085"
```

## LAN Offline Export

The LAN menu must work without Cloudflare or GitHub. Export the WPF engine and
LAN bootstrapper into the private LAN folder served by Caddy:

```powershell
.\tools\export-lan-launcher.ps1 -DestinationPath \\NAS\WindowsUtilScripts -LanBaseUrl https://get.home.us
```

For temporary IP testing:

```powershell
.\tools\export-lan-launcher.ps1 -DestinationPath \\NAS\WindowsUtilScripts -LanBaseUrl http://SERVER-IP:8085 -Force
```

The helper writes:

```text
launcher
launcher.ps1
lib/wpf-menu-engine.ps1
lan-manifest.example.json
```

It does not copy private scripts, installers, credentials, `.env` files, or Git
metadata.

## Manifest Schema

WAN and LAN manifests use the same `items` schema. Keep compatibility with
`config/apps.json` fields:

- `id`
- `name`
- `category`
- `description`
- `default`
- `method`
- `payload`
- `url`
- `file`
- `args`
- `detect`
- `check`
- `fallback`

Supported methods:

- `winget`
- `choco`
- `download`
- `script`
- `irm`

Example LAN item:

```json
{
  "id": "lan-diagnostics",
  "name": "LAN Diagnostics",
  "category": "LAN Tools",
  "description": "Run basic LAN diagnostics.",
  "default": false,
  "method": "script",
  "payload": "scripts/lan-diagnostics.ps1"
}
```

In LAN mode, `scripts/lan-diagnostics.ps1` resolves to:

```text
$LanBaseUrl/scripts/lan-diagnostics.ps1
```

The harmless example structure in `examples/private-script-source/` can be
copied to your NAS/private folder as a starting point.

## Security Notes

- Do not put secrets in the manifest.
- Do not put private LAN scripts in public GitHub.
- Do not expose the LAN Caddy server directly to the internet.
- Keep Caddy private IP restrictions in place.
- Treat the LAN tool menu as convenience, not access control.
- LAN-only scripts must remain protected by Caddy and firewall rules.
- Consider HTTPS and an internal certificate later if credentials or sensitive
  workflows are ever introduced.
