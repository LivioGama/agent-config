---
root: false
targets: ["*"]
description: "Infra: Dokploy/self-hosted VPS, Turborepo, Vercel, .env from shell"
globs: ["**/*"]
---

# Infrastructure & Deployment

## Self-Hosted via Dokploy

When asked to fix/debug a URL ending in `.liviogama.com` or `.devliv.io` — **unless** Vercel/Netlify/Cloudflare Pages or another external host is mentioned — assume it is **self-hosted on my own infra, managed by Dokploy**. Do NOT treat it as a third-party platform.

| Domain suffix     | Server  | SSH           | IP             | Dokploy panel                  |
|-------------------|---------|---------------|----------------|--------------------------------|
| `*.liviogama.com` | genesis | `ssh genesis` | 100.105.74.25  | https://dokploy.liviogama.com  |
| `*.devliv.io`     | exodus  | `ssh exodus`  | 100.113.187.15 | https://dokploy.devliv.io      |

### Debugging workflow (in order)
1. **Dokploy CLI locally** (`dokploy ...`, config `~/.dokploy/config.json`): `project all`, `compose update|deploy`, `application ...`, read-logs, read-traefik-config.
2. **SSH into the host** (`ssh genesis` / `ssh exodus`). Docker runs as root → prefix `sudo`:
   - `sudo docker ps` / `sudo docker logs <c>` — status & logs
   - `sudo docker inspect <c>` — networks, labels, env
   - Traefik runs as a swarm service (`traefik.1.*`) on networks `dokploy-network` + `ingress`
   - Generated compose: `/etc/dokploy/compose/<app>/code/docker-compose.yml`
3. Check Traefik routing, docker logs, and env vars before concluding.

### Common 504 Gateway Timeout
Traefik can only reach a container that shares the external `dokploy-network`. If a compose service is only on its per-app network → 504. Fix by attaching it in the stored composeFile:
```yaml
services:
  <service>:
    networks: [dokploy-network]
networks:
  dokploy-network:
    external: true
```
Then `dokploy compose update --composeId <id> --composeFile "<yaml>"` + `dokploy compose deploy --composeId <id>`. Verify the container joined `dokploy-network` via `sudo docker inspect` and the URL returns 200.

**Note:** CLI `compose one` (read) errors HTTP 400 — fetch compose details via REST: `GET https://<panel>/api/compose.one?composeId=<id>` with header `x-api-key: <token>`. Mutations (`update`/`deploy`) work fine via CLI.

## Turborepo
- **Never** use `"ui": "tui"` in `turbo.json` — omit `ui` or use `"ui": "stream"`.
- **Pre-push gate:** run `turbo build` before any `git push`; fix errors and retry until it passes. Never push with a broken build.

## Vercel
- Before the **first** Vercel deploy of a Next.js project, run the `/vercel-first-deploy` skill. Blocking — do not skip.

## .env Population from Shell Profile
When creating/populating a `.env`, **before asking the user**, scan `~/.zshrc` (and `~/.zprofile` if present) for matching `export` lines:
- LLM keys (OPENAI/ANTHROPIC/GOOGLE/GEMINI/GROQ/etc.), SaaS/infra (STRIPE/RESEND/SUPABASE/TURSO/UPSTASH/etc.), auth (AUTH_SECRET/CLERK/NEXTAUTH), cloud (AWS/CLOUDFLARE/VERCEL), and any `*_API_KEY` / `*_SECRET` / `*_TOKEN`.
- Read via the Read tool; handle `export KEY="value"` and `export KEY=value`.
- Auto-fill matched keys silently; **zshrc value wins** over `.env.example`. Mention what was auto-filled.
- Ask the user or leave a placeholder only for unmatched keys.
- **Never** log or echo actual secret values.
