# LAN-Aware Launcher

The public launcher is intended to be run from anywhere:

```powershell
irm https://get.tand.us/launcher | iex
```

It always opens the main public menu first. The main menu includes a LAN Mode
option. When the same launcher is run from inside the LAN, it probes an
internal-only manifest endpoint and marks LAN Mode as detected if the manifest
is reachable and trusted.

## Why the launcher probes the LAN

The Cloudflare Worker cannot reliably determine whether the original client is
on the private LAN. Depending on routing, proxying, and NAT, Cloudflare may only
see the public WAN address. That is not enough to decide whether LAN-only tools
should be shown.

Instead, the launcher runs on the Windows client and probes an internal-only
endpoint:

```text
http://scripts.home.arpa:8085/lan-manifest.json
```

It also tries the optional alternate endpoint:

```text
http://get-lan.tand.us:8085/lan-manifest.json
```

If no endpoint responds quickly, LAN Mode remains available from the main menu
and prompts for a manual LAN base URL. This keeps the public launcher responsive
outside the LAN while still allowing IP-based LAN use.

## LAN detection order

The launcher tries LAN base URLs in this order:

1. The `-LanBaseUrl` parameter.
2. The `TAND_LAN_BASE_URL` environment variable.
3. User config at `%APPDATA%\TAND\WindowsUtil\config.json`.
4. Default internal DNS candidates:
   - `http://scripts.home.arpa:8085`
   - `http://windows-util-scripts.home.arpa:8085`
   - `http://windows-util-scripts.local:8085`

Each candidate is tested with `GET /lan-manifest.json` and a short timeout.
Private IP addresses are not hardcoded as defaults in this public repo.

## Manual LAN URL

If auto-detection fails, choose LAN Mode and enter the LAN base URL manually:

```text
http://SERVER-IP:8085
```

The launcher trims trailing slashes, validates
`http://SERVER-IP:8085/lan-manifest.json`, and can save the working URL for the
current user:

```text
%APPDATA%\TAND\WindowsUtil\config.json
```

Example saved config:

```json
{
  "LanBaseUrl": "http://SERVER-IP:8085"
}
```

## Environment override

Set a persistent user environment variable:

```powershell
[Environment]::SetEnvironmentVariable("TAND_LAN_BASE_URL", "http://SERVER-IP:8085", "User")
```

For the current PowerShell session only:

```powershell
$env:TAND_LAN_BASE_URL = "http://SERVER-IP:8085"
```

## Advanced launch examples

Simple usage still opens the main menu:

```powershell
irm https://get.tand.us/launcher | iex
```

Parameter usage:

```powershell
$script = irm https://get.tand.us/launcher
& ([scriptblock]::Create($script)) -Lan
& ([scriptblock]::Create($script)) -Lan -LanBaseUrl 'http://SERVER-IP:8085'
& ([scriptblock]::Create($script)) -DebugLan
```

Use `D. Diagnostics / Debug` from the launcher menus, or `-DebugLan`, to show
candidate LAN URLs tested, manifest test results, and the selected LAN base URL.

## Internal DNS

Create an internal DNS record that resolves only on the private network:

```text
scripts.home.arpa -> LAN server IP
```

Optional alternate internal DNS:

```text
get-lan.tand.us -> LAN server IP
```

The exact internal DNS names can be changed later in `scripts/launcher.ps1`.

## Manifest marker

The LAN manifest must include this marker:

```json
{
  "marker": "TAND-LAN-LAUNCHER-v1"
}
```

The launcher treats LAN mode as available only when the manifest is reachable
and the marker matches exactly. A DNS failure, timeout, HTTP failure, invalid
JSON response, or marker mismatch keeps LAN Tools hidden.

## Adding LAN tools

Add LAN-only tools to `lan-manifest.json` inside the private script source
folder configured by `LAN_SCRIPT_SOURCE`, not to this public GitHub repo:

```json
{
  "id": "example-tool",
  "name": "Example Tool",
  "scriptUrl": "http://scripts.home.arpa:8085/lan/example-tool.ps1"
}
```

Then add the script under the private source folder's `lan/` subfolder and
update the launcher menu logic if the tool needs a dedicated menu option. The
harmless example structure in `examples/private-script-source/` can be copied to
your NAS/private folder as a starting point.

Keep LAN scripts safe to review and run with:

```powershell
irm http://scripts.home.arpa:8085/lan/example-tool.ps1
```

Only pipe to `iex` after reviewing the returned script.

## Security notes

- Do not put secrets in the manifest.
- Do not put private LAN scripts in public GitHub.
- Do not expose the LAN Caddy server directly to the internet.
- Keep Caddy private IP restrictions in place.
- Treat the LAN tool menu as convenience, not access control.
- LAN-only scripts must remain protected by Caddy and firewall rules.
- Consider HTTPS and an internal certificate later if credentials or sensitive
  workflows are ever introduced.
