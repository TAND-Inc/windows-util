# LAN Caddy Hosting

## Overview

The LAN Caddy stack serves PowerShell scripts from a private folder on the
Docker host. The GitHub repo contains deployment scaffolding, documentation, and
safe examples only. The actual LAN scripts live outside GitHub, typically on a
NAS share mounted onto the Docker host.

At runtime, the container mounts the private folder read-only at `/srv/scripts`
and generates its Caddyfile inside the container. No repo script folder,
`lan/` folder, or Caddyfile is bind-mounted into the container.

## Why LAN Scripts Are Not Stored In GitHub

LAN scripts can contain internal workflows, hostnames, operational assumptions,
or commands that should not be published. Keeping them in a NAS-mounted or
private host folder lets Portainer deploy this public repo while Caddy serves
only private LAN content.

The menu hiding in the public launcher is convenience only. The security
boundary is the private script source, the Caddy LAN IP restrictions, firewall
rules, and NAS permissions.

## Preparing The Private Script Folder

Create a private folder on the Docker host, for example:

```text
/mnt/windows-util-scripts
```

The folder must already exist before starting the Portainer stack. The compose
file uses `create_host_path: false`, so a missing path fails instead of Docker
silently creating and serving an empty folder.

Use `examples/private-script-source/` as a harmless starting point, then copy the
real scripts into your private NAS or Docker host folder.

Export the public-safe WPF LAN bootstrap and engine into that same private
folder:

```powershell
.\tools\export-lan-launcher.ps1 -DestinationPath \\NAS\WindowsUtilScripts -LanBaseUrl https://get.home.us
```

For temporary IP testing:

```powershell
.\tools\export-lan-launcher.ps1 -DestinationPath \\NAS\WindowsUtilScripts -LanBaseUrl http://SERVER-IP:8085 -Force
```

## Example Private Script Folder Structure

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

The LAN-aware public launcher expects `lan-manifest.json` to include:

```json
{
  "marker": "TAND-LAN-LAUNCHER-v1"
}
```

Do not put secrets in the manifest.

## Mounting A NAS Share On The Docker Host

Example for an Ubuntu/Debian Docker host using SMB/CIFS:

```bash
sudo apt update
sudo apt install -y cifs-utils
sudo mkdir -p /mnt/windows-util-scripts
sudo nano /etc/samba/windows-util-scripts.cred
sudo chmod 600 /etc/samba/windows-util-scripts.cred
sudo nano /etc/fstab
sudo mount -a
mountpoint /mnt/windows-util-scripts
ls -la /mnt/windows-util-scripts
```

Example `/etc/fstab` line:

```text
//NAS-IP-OR-NAME/WindowsUtilScripts /mnt/windows-util-scripts cifs credentials=/etc/samba/windows-util-scripts.cred,iocharset=utf8,vers=3.0,file_mode=0644,dir_mode=0755,nofail,x-systemd.automount 0 0
```

Use placeholder values only in docs and config. Prefer a read-only NAS user if
possible.

## Portainer Git Stack Settings

Create a Portainer Git Repository stack with:

```text
Repository URL: <this repository URL>
Compose path: docker-compose.yml
```

The stack uses `caddy:2-alpine` directly and mounts only the private script
folder configured by `LAN_SCRIPT_SOURCE`.

## Required Environment Variables

Set these in Portainer:

```text
LAN_SCRIPT_SOURCE=/mnt/windows-util-scripts
LAN_SCRIPT_PORT=8085
```

`LAN_SCRIPT_SOURCE` must be an absolute path on the Docker host. It should point
to a NAS-mounted or private local folder and must already exist.

## Testing The Service

Replace `SERVER-IP` with the IP address of the Docker host:

```powershell
irm http://SERVER-IP:8085/install.ps1
irm http://SERVER-IP:8085/install.ps1 | iex
irm http://SERVER-IP:8085/dev.ps1 | iex
irm http://SERVER-IP:8085/uninstall.ps1 | iex
irm http://SERVER-IP:8085/launcher | iex
irm http://SERVER-IP:8085/lan-manifest.json
irm http://SERVER-IP:8085/scripts/lan-diagnostics.ps1 | iex
```

If you create internal DNS:

```text
scripts.home.arpa -> SERVER-IP
```

Then test:

```powershell
irm http://scripts.home.arpa:8085/install.ps1 | iex
irm http://scripts.home.arpa:8085/launcher | iex
irm http://scripts.home.arpa:8085/scripts/lan-diagnostics.ps1 | iex
```

## Troubleshooting

If PowerShell returns `404`:

- The container can be reached, but the file is not present under
  `/srv/scripts`.
- Check the Docker host path:

```bash
ls -la /mnt/windows-util-scripts
```

- Check inside the container:

```bash
docker exec -it windows-util-scripts sh
ls -la /srv/scripts
```

If `/srv/scripts` is empty:

- `LAN_SCRIPT_SOURCE` is wrong, not mounted, or points to an empty folder.
- Verify the NAS mount exists on the Docker host before starting the stack.

If deployment fails because `LAN_SCRIPT_SOURCE` is missing:

- That is expected and safer than Docker silently creating an empty folder.
- Mount the NAS share or correct the path.

If Caddy returns `403 Forbidden`:

- The client IP is not in RFC1918 LAN ranges, or traffic is coming through a
  proxy/VPN.
- Test directly from a LAN client to `SERVER-IP:8085`.

Keep this service behind internal DNS and firewall rules. Do not expose the LAN
Caddy container directly to the internet.
