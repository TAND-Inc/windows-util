# LAN-Aware Launcher

The public launcher is intended to be run from anywhere:

```powershell
irm https://get.tand.us/launcher | iex
```

It always shows public tools. When the same launcher is run from inside the LAN,
it probes an internal-only manifest endpoint and shows an extra LAN Tools menu if
the manifest is reachable and trusted.

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

If neither endpoint responds quickly, LAN mode stays hidden. This keeps the
public launcher responsive outside the LAN.

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

Add LAN-only tools to `lan/lan-manifest.json`:

```json
{
  "id": "example-tool",
  "name": "Example Tool",
  "scriptUrl": "http://scripts.home.arpa:8085/lan/example-tool.ps1"
}
```

Then add the script under `lan/` and update the launcher menu logic if the tool
needs a dedicated menu option. Keep LAN scripts safe to review and run with:

```powershell
irm http://scripts.home.arpa:8085/lan/example-tool.ps1
```

Only pipe to `iex` after reviewing the returned script.

## Security notes

- Do not put secrets in the manifest.
- Do not expose the LAN Caddy server directly to the internet.
- Keep Caddy private IP restrictions in place.
- Treat the LAN tool menu as convenience, not access control.
- LAN-only scripts must remain protected by Caddy and firewall rules.
- Consider HTTPS and an internal certificate later if credentials or sensitive
  workflows are ever introduced.
