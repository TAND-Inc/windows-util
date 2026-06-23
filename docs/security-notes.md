# Security Notes

`irm <url> | iex` is convenient, but it downloads code and immediately executes
it in the current PowerShell session. Treat it as remote code execution and use
it only with scripts and domains you control and trust.

## Public Scripts

- Use HTTPS for public script delivery.
- Prefer GitHub releases or tags for stable public commands.
- Avoid serving directly from `main` for production use.
- Review scripts before tagging a release.
- Do not store secrets in scripts, docs, compose files, Worker code, or examples.

## LAN Scripts

- Keep LAN-only scripts behind internal DNS and firewall rules.
- Restrict the Caddy container to private network clients.
- Do not expose the LAN Caddy container directly to the internet.
- Use placeholder domains in public docs and examples.
- Do not put private LAN scripts in public GitHub.
- Keep the NAS share permission-limited.
- Use a read-only NAS user for the Caddy container's source folder where
  possible.
- `irm | iex` is powerful and should only be used with trusted internal hosts.

## Future Hardening

Consider code signing if these scripts become widely distributed. For larger
payloads, consider hash validation before execution or installation. If scripts
download installers, prefer vendor HTTPS URLs and stable release artifacts.
Consider HTTPS internally later if needed; HTTP is acceptable for a tightly
controlled LAN-only first version.
