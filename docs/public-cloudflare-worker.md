# Public Cloudflare Worker Hosting

This project can expose friendly public commands such as:

```powershell
irm https://scripts.example.com/install | iex
irm https://scripts.example.com/dev | iex
irm https://scripts.example.com/uninstall | iex
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


## Deploy

One simple workflow is:

1. Create a Cloudflare Worker.
2. Paste the contents of `worker/cloudflare-worker.js`.
3. Set the placeholder GitHub owner, repo, and tag.
4. Save and deploy the Worker.
5. Add a Worker route for `scripts.example.com/*`.
6. Point the DNS record for `scripts.example.com` at Cloudflare.

Cloudflare can also be managed with Wrangler if you prefer a CLI workflow. This
repo does not require Wrangler or any Node dependencies.


## Test

After deployment, verify that each route returns the expected PowerShell text:

```powershell
irm https://scripts.example.com/install
irm https://scripts.example.com/dev
irm https://scripts.example.com/uninstall
```

Only pipe to `iex` after reviewing the returned script:

```powershell
irm https://scripts.example.com/install | iex
```
