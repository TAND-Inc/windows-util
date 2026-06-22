# Public Cloudflare Worker Hosting

This project can expose friendly public commands such as:

```powershell
irm https://get.tand.us/install | iex
irm https://get.tand.us/dev | iex
irm https://get.tand.us/uninstall | iex
```

The Worker in `worker/cloudflare-worker.js` receives those routes, fetches the matching PowerShell file from GitHub raw content, and returns it as plain text.


## Configure the Worker

Edit `worker/cloudflare-worker.js` and replace the placeholder GitHub values:

```javascript
const GITHUB_OWNER = "TAND-Inc";
const GITHUB_REPO = "windows-util";
const GITHUB_REF = "main";
```

Use `main` for early testing before the first release tag exists. Use a release
tag such as `v0.1.0` for `GITHUB_REF` when exposing a public command. A branch
changes whenever new commits are pushed; a tag gives users a stable script until
you intentionally publish a new tag and update the Worker.

The root `wrangler.toml` is used by Cloudflare's Git-backed Worker build:

```toml
name = "windows-util"
main = "worker/cloudflare-worker.js"
compatibility_date = "2026-06-22"
workers_dev = false

[route]
pattern = "get.tand.us/*"
zone_name = "tand.us"
```


## Deploy

### Dashboard paste workflow

One simple manual workflow is:

1. Create a Cloudflare Worker.
2. Paste the contents of `worker/cloudflare-worker.js`.
3. Set the placeholder GitHub owner, repo, and tag.
4. Save and deploy the Worker.
5. Add a Worker route for `get.tand.us/*`.
6. Point the DNS record for `get.tand.us` at Cloudflare.

### Git-backed Worker build

When the Worker is connected to this GitHub repo, leave the build command blank
and keep the root directory blank so Cloudflare runs from the repository root.
Use the default deploy command:

```text
npx wrangler deploy
```

Cloudflare reads `wrangler.toml` to find the Worker entrypoint and route. This
repo does not require a package.json, install step, or Node dependencies.


## Test

After deployment, verify that each route returns the expected PowerShell text:

```powershell
irm https://get.tand.us/health
irm https://get.tand.us/install
irm https://get.tand.us/dev
irm https://get.tand.us/uninstall
```

Only pipe to `iex` after reviewing the returned script:

```powershell
irm https://get.tand.us/install | iex
```
