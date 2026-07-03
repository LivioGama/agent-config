---
root: false
targets: ["*"]
description: "Tooling: rtk, GitNexus, context7, agent-browser, Claude auth"
globs: ["**/*"]
---

# Tooling Conventions

## RTK (Rust Token Killer) — prefix every shell command

ALWAYS prefix shell commands with `rtk`. It applies a token-saving filter when it has one and passes unknown commands through unchanged, so it is always safe.

- Use `rtk` even inside `&&` chains: `rtk git add && rtk git commit -m "msg" && rtk git push`.
- Substitutions:
  - `ls`/`tree` → `rtk ls <path>`
  - `cat`/`head`/`tail` → `rtk read <file>` (`-l aggressive` for code)
  - `find`/`fd` → `rtk find <pattern>`
  - `grep`/`rg` → `rtk grep <pattern>`
  - `git *` → `rtk git *` (status, log, diff, add, commit, push, pull — passthrough covers all subcommands)
  - tests → `rtk test <cmd>` / `rtk cargo test` / `rtk jest` / `rtk vitest` / `rtk pytest` / `rtk playwright test`
  - builds → `rtk tsc` / `rtk lint` / `rtk next build` / `rtk cargo build` / `rtk prettier --check`
  - containers → `rtk docker ps|images|logs` / `rtk kubectl get|logs`
  - errors only → `rtk err <cmd>`; logs deduped → `rtk log <file>`
  - data → `rtk json <file>`, `rtk deps`, `rtk env -f <filter>`
- `rtk proxy <cmd>` runs a command WITHOUT filtering (debugging only).
- **`rtk` is installed on ALL machines — Mac, genesis, exodus.** Use it for remote command output too (over SSH and inside remote agent sessions) so VPS output stays token-cheap. If a VPS is missing `rtk`, the orchestrator bootstrap installs it.

## GitNexus — index-powered exploration over grep/find

After `bunx gitnexus analyze`, use `gitnexus_*` tools instead of grep/find/manual reading. Think in processes and flows, not files.

- BEFORE editing any symbol: `gitnexus_impact({target, direction: "upstream"})` — report callers, affected processes, risk.
- BEFORE commit: `gitnexus_detect_changes()` — verify scope.
- Find code: `gitnexus_context({name})` (callers/callees), `gitnexus_query({query})` (by concept/flow).
- Explore: `gitnexus_clusters()`, `gitnexus_processes()`, `gitnexus_process({name})`.
- Refactor safely: `gitnexus_rename(...)` / `gitnexus_extract(...)` — never find-and-replace.

## context7 (`ctx7`) — fetch current docs before answering

Whenever working with any library, framework, SDK, API, CLI tool, or cloud service (even well-known ones — React, Next.js, Tailwind, etc.), fetch current docs. Prefer over web search for library docs.

1. `bunx ctx7@latest library <name> "<question>"` → pick best `/org/project` ID.
2. `bunx ctx7@latest docs <id> "<question>"` → answer from the docs.

Do NOT use for refactoring, business-logic debugging, code review, or scripts from scratch.

## Browser automation — efficient by default

Prefer `agent-browser` (at `/opt/homebrew/bin/agent-browser`) for programmatic browser automation when needed. Optimize for fast, low-noise verification: use headless by default, reuse sessions, and open your default browser to access remote Chrome only when visual judgment is actually part of the task.

- **Default: headless Lightpanda** for routine navigation, smoke checks, console/network inspection, DOM assertions, screenshots, and regression loops:
  ```
  agent-browser --engine lightpanda --session main <cmd>
  ```
- **Use default browser to access remote Chrome for visualization**: When the task requires visual judgment, debugging requires DevTools, or headless cannot reproduce the issue, automatically open your default browser to access the remote Chrome instance configured in your environment. Retrieve the URL and credentials from your local password manager (e.g. Proton Pass) or environment variables — never commit credentials to the repo.
  ```
  open "$CHROME_REMOTE_URL"
  # Enter credentials from your password manager when prompted
  ```
- **Note**: For non-headless testing, remote Chrome is the default. Use local Brave only when explicitly requested for quick local checks.
- **Reuse the already-open browser** via a named session — NEVER spawn a new browser per call: `agent-browser --session <name> <cmd>`. Default session name `main`.
- **When debugging, always capture network + console logs** (not just screenshots): `agent-browser --session <name> console` and `... network` to see errors/requests.
- Parallelize via additional isolated `--session <name>`; pass `--json` for structured `{success, data, error}`.
- **Remote browserless** (only when asked): `agent-browser --session bl connect "https://browserless.liviogama.com?token=<token>"` then `open/screenshot/close` on `--session bl`.
- **Electron apps**: drive the running Electron renderer via agent-browser's Electron/CDP connect path — do not launch a second browser.

## suparun — fast self-hosted run-on-VPS (on demand, not automatic)

`suparun` (https://github.com/LivioGama/suparun, no UI needed) is installed globally on the Mac and both VPS. Use it ONLY when asked, configured per-vhost. Not a default behavior.

## Skills — one canonical source, fan out (never edit per-tool copies)

Skills are CENTRALIZED. The single source of truth is **`.agent-config/skills/`** (within the agent-config repo) — author and edit every shared skill THERE, once.

- After creating/editing a skill, run **`./sync-skills.sh`** (called automatically by `./build.sh`): it fans the canonical set out to `~/.codex/skills`, `~/.cursor/skills`, `~/.gemini/skills`, `~/.devin/skills`, `~/.claude/skills`, and re-vaults via chezmoi so genesis + exodus get it too.
- The fanout is ADDITIVE — each tool keeps its own tool-specific skills (e.g. codex `codex-primary-runtime`/`harness`, cursor `gitnexus-*`). Those tool-specific ones may be edited in place.
- NEVER hand-edit a shared skill inside `~/.codex|.cursor|.gemini|.devin|.claude/skills` — it will be overwritten on the next sync. Edit the canonical `.agent-config/skills/<name>/SKILL.md`.
- Deleting a shared skill everywhere is a job for the cleanup-console, not the fanout.

## Claude auth — OAuth ONLY, `ANTHROPIC_API_KEY` is BANNED everywhere

`ANTHROPIC_API_KEY` must NEVER exist or be used anywhere on this machine — not in shell profiles, not in app/tool configs, not in any subprocess env, for ANY tool (Claude Code, Codex, scripts, CI, everything). The user has banned it permanently and absolutely.

- All Claude tooling authenticates via OAuth / keychain login (`claude /login`) or `CLAUDE_CODE_OAUTH_TOKEN` only.
- A stray `ANTHROPIC_API_KEY` silently overrides OAuth → `401 Invalid API key` → agents/CLIs crash-loop. This already broke a Liza pipeline once.
- It is unset by design: `~/.zshenv` contains `unset ANTHROPIC_API_KEY` (covers all zsh-spawned processes) and it is not in `launchctl`.
- If you EVER see `ANTHROPIC_API_KEY` set or exported anywhere, remove it immediately (delete the export, keep the `unset` guard) — do not ask, just remove. Never add it back for any reason.

## Swarness project — ACP client, never acpx

In the Swarness project: NEVER use `acpx` (no `bunx acpx`, no acpx subprocess calls). Use the ACP client directly (`src/acpClient.ts`) — it provides proper streaming and session management. Run the app with `bun run dev:electron` (the Electron build with auto-reload), not `bun run dev` (web, no filesystem access).

## Browser testing

Never use local Chrome for testing. Use headless Lightpanda by default for programmatic testing, or open your default browser to access remote Chrome when visual verification is necessary.

Use agent-browser for programmatic browser automation when needed. Prefer `--engine lightpanda`; for visual review, open your default browser to access remote Chrome using the URL configured in your environment.

## Non-headless browser testing — remote Chrome by default, local Brave on request

When running browser tests that require non-headless (visible) execution:

- **DEFAULT**: Open your default browser to access the remote Chrome instance using the URL configured in your environment. Retrieve credentials from your local password manager (e.g. Proton Pass) or environment variables.
- **EXCEPTION**: When user explicitly requests local Brave for quick checks

### Remote Chrome (default for visualization)
- **Remote Chrome instance**: use the URL configured in your environment (e.g. `$CHROME_REMOTE_URL`); never commit the URL or credentials to the repo
- **Authentication**: retrieve credentials from your password manager or environment variables; never hardcode them
- **Features**: Dark theme enabled, Proton Pass ready for installation
- **Usage**: Open the URL in your default browser, enter credentials when prompted

### Required remote Chrome usage patterns:
- **Automatic opening**: Always use `open "$CHROME_REMOTE_URL"` when visualization is needed
- **Authentication**: Enter credentials from your password manager when prompted
- **Never use local browsers** for visualization unless explicitly requested
- **Always use remote Chrome** for debugging, visual review, and interactive testing

### Local Brave (only when explicitly requested)
- Use headed local Brave only when user explicitly asks for quick local checks
- Do not use local Brave as the default for non-headless testing
- Invocation: `agent-browser --headed --executable-path "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" --session main <cmd>`

### Examples:
```bash
# Remote Chrome (default for visualization)
open "$CHROME_REMOTE_URL"
# Enter credentials from your password manager when prompted

# Local Brave (only when user explicitly requests quick check)
agent-browser --headed --executable-path "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" --session main screenshot
```

### Auto-open requirement
When visualization is required, ALWAYS automatically open your default browser to access remote Chrome:
- **Visualization tasks**: Use `open "$CHROME_REMOTE_URL"` to launch your default browser
- **Interactive testing**: Navigate to your local dev server from within the remote Chrome
- **Never skip the auto-open** when visual judgment is part of the task

This ensures visualization tasks default to the properly configured remote Chrome infrastructure while allowing local Brave for quick checks when requested.
