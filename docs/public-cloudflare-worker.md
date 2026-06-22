# Public Cloudflare Worker Hosting

This project exposes friendly public commands through a Cloudflare Worker Custom
Domain:

```powershell
irm https://get.tand.us/install | iex
irm https://get.tand.us/dev | iex
irm https://get.tand.us/uninstall | iex
```

The Worker in `worker/cloudflare-worker.js` receives requests for `get.tand.us`,
fetches the matching PowerShell file from GitHub raw content, and returns it as
plain text. No separate origin server is needed; the Worker is the origin for
`get.tand.us`.

## Recommended setup: Custom Domain

Use a Cloudflare Worker Custom Domain for this project. It is cleaner than a
traditional Worker Route because Cloudflare attaches the hostname directly to the
Worker and manages the DNS record and SSL certificate for the Custom Domain.

The root `wrangler.toml` uses this Custom Domain configuration:

```toml
name = "windows-util"
main = "worker/cloudflare-worker.js"
compatibility_date = "2026-06-22"
workers_dev = false

[[routes]]
pattern = "get.tand.us"
custom_domain = true
```

Do not use `/*` with `custom_domain = true`. The Worker still receives all paths
under `https://get.tand.us`, including `/install`, `/dev`, `/uninstall`, and
`/health`.

If a DNS record named `get` already exists in the `tand.us` zone, Cloudflare may
report a hostname or DNS conflict when adding the Custom Domain. Delete the
conflicting `get` record first, then add the Worker Custom Domain again.

## Configure the Worker

Edit `worker/cloudflare-worker.js` if the GitHub source changes:

```javascript
const GITHUB_OWNER = "TAND-Inc";
const GITHUB_REPO = "windows-util";
const GITHUB_REF = "main";
```

Use `main` for early testing before the first release tag exists. Use a release
tag such as `v0.1.0` for `GITHUB_REF` when exposing a public command. A branch
changes whenever new commits are pushed; a tag gives users a stable script until
you intentionally publish a new tag and update the Worker.

## Manual Cloudflare steps

```text
1. Log in to Cloudflare.
2. Go to Workers & Pages.
3. Open the `windows-util` Worker, or create it if it does not exist.
4. Confirm the Worker code points to `worker/cloudflare-worker.js`.
5. Go to the Worker's Settings.
6. Open Domains & Routes.
7. Click Add.
8. Choose Custom Domain.
9. Enter `get.tand.us`.
10. Select the `tand.us` zone if prompted.
11. Save.
12. Wait for Cloudflare to provision the DNS record and SSL certificate.
13. Test `https://get.tand.us/health`.
14. Test `https://get.tand.us/install` and confirm it returns PowerShell text.
15. Only after confirming the content, test `irm https://get.tand.us/install | iex`.
```

Troubleshooting:

```text
If Cloudflare says the hostname already exists or DNS conflicts with the Custom Domain, go to:
tand.us -> DNS -> Records
and remove any existing record named `get`, then try adding the Custom Domain again.
```

## Git-backed Worker build

When the Worker is connected to this GitHub repo, leave the build command blank
and keep the root directory blank so Cloudflare runs from the repository root.
Use the default deploy command:

```text
npx wrangler deploy
```

Cloudflare reads `wrangler.toml` to find the Worker entrypoint and Custom Domain.
This repo does not require a package.json, install step, or Node dependencies.
Cloudflare deployment and domain attachment are manual unless Wrangler
authentication is configured.

## Test

After deployment, verify that each route returns the expected plain text before
executing anything:

```powershell
irm https://get.tand.us/health
irm https://get.tand.us/install
irm https://get.tand.us/dev
irm https://get.tand.us/uninstall
```

Only pipe to `iex` after reviewing the returned script:

```powershell
irm https://get.tand.us/install | iex
irm https://get.tand.us/dev | iex
irm https://get.tand.us/uninstall | iex
```

## Alternative: traditional Worker Route

A traditional Worker Route is not recommended for this project, but it can work.
That setup would require:

- A proxied DNS record for `get.tand.us`.
- A Worker route such as `get.tand.us/*`.
- A placeholder proxied AAAA record such as `100::` if there is no real origin.

The Custom Domain setup above avoids the placeholder origin record and lets
Cloudflare attach the hostname directly to the Worker.
