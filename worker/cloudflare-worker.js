// Cloudflare Worker for friendly PowerShell script routes.
//
// Replace these placeholders before deploying:
//   GITHUB_OWNER: your GitHub username or organization
//   GITHUB_REPO:  your repository name
//   GITHUB_REF:   use "main" for early testing; prefer a release tag such as
//                 "v0.1.0" for public use
//
// Example public commands:
//   irm https://scripts.example.com/install | iex
//   irm https://scripts.example.com/dev | iex
//   irm https://scripts.example.com/uninstall | iex

const GITHUB_OWNER = "TAND-Inc";
const GITHUB_REPO = "windows-util";
const GITHUB_REF = "main";

const ROUTES = {
  "/install": "scripts/install.ps1",
  "/dev": "scripts/dev.ps1",
  "/uninstall": "scripts/uninstall.ps1",
};

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const scriptPath = ROUTES[url.pathname.replace(/\/$/, "")];

    if (!scriptPath) {
      return new Response("Not found\n", {
        status: 404,
        headers: {
          "Content-Type": "text/plain; charset=utf-8",
          "Cache-Control": "no-cache",
        },
      });
    }

    const rawUrl = `https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPO}/${GITHUB_REF}/${scriptPath}`;
    const upstream = await fetch(rawUrl, {
      headers: {
        "User-Agent": "windows-script-distribution-worker",
      },
    });

    if (!upstream.ok) {
      return new Response(`Failed to fetch script: ${upstream.status}\n`, {
        status: 502,
        headers: {
          "Content-Type": "text/plain; charset=utf-8",
          "Cache-Control": "no-cache",
        },
      });
    }

    return new Response(await upstream.text(), {
      status: 200,
      headers: {
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": "no-cache",
      },
    });
  },
};
