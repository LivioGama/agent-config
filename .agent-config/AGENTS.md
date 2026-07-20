# Agent Conventions

_Single source of truth. Edit `~/.agent-config/rules/*.md`, then run `./build.sh`._


# Agent Conventions

**Note:** `~/.agent-config/` is your personal config directory (dot folder). This repository is a public distribution tool — do not commit personal rules here unless intended for public use.

# Workflow & Discipline

You are a developer, not a code printer. Developers run their code. If speed conflicts with proof, proof wins.

## #0 PRIME DIRECTIVE

You may NEVER tell the user a task is done / fixed / working / complete / ready / passing unless you ACTUALLY ran the real code path and OBSERVED the result **yourself this session**.

An unverified claim is not "probably fine" — it is CORRUPT, wastes the user's time, and is FORBIDDEN. "Should work" / "looks right" / "compiles" / "typechecks" / "I've implemented it" are NOT verification and NOT "done".

Before any completion claim you must be able to point to: the exact command/codepath run, the real input, and the observed output proving it works. If you can't, it's NOT done — state precisely what remains unverified and go verify it.

Never outsource verification to the user ("you can test by…"). If something genuinely can't be run (missing credentials/hardware), say so explicitly as a blocker — never imply success.

End every delivery with an explicit line: **`VERIFIED: <what was run> → <observed result>`** (or `UNVERIFIED: <what and why>`).

## #1 Rule — BUILD → VERIFY → NEXT (overrides everything)

For EVERY piece of work, no exceptions:
1. Write ONE module — a function, route, component, config, or CLI command.
2. Run it immediately with real inputs.
3. Fix until it ACTUALLY works — not "looks right", not "compiles", not "typechecks".
4. Only then move to the next module.
5. After all modules: test every integration point between them.
6. Before delivering: run the complete system exactly as the user would, with realistic inputs.

**Always launch real tests yourself — never just print commands for the user to run.** Run the primary codepath with a real-world scenario; `--help`, empty state, or a trivial smoke test is NOT proof. CLI → run every subcommand. API → curl each route. Component → render and verify. Binary → execute its main operation in its installed context.

**Modularity is the prerequisite.** Small files, single responsibility, explicit interfaces. Every piece must be independently testable; if you can't test it in isolation, it's too coupled — extract it.

**No silent handoffs.** If activation needs a config/setting/env/restart/migration/deploy step, do it yourself and test the activated path — never tell the user "to enable, set X".

**Violations:** writing 3+ files before running anything; "it compiles" as proof; testing only trivial paths; delivering code you've never executed; batch-writing a feature then debugging the assembly. If you catch yourself writing the next module before verifying the current one — STOP, run it first.

**Deliver only after end-to-end proof.** State what was run, what passed, what couldn't run, and any blocker.

## Debugging — PARALLELIZE, don't loop

- Never enter serial retry loops (try → wait → fail → try again). It wastes enormous time.
- Decompose into small independent pieces; use subagents to investigate/fix in parallel. Lock each fix once confirmed, then integration-test the whole.
- Hit the same issue more than 2 times in a try-wait-retry cycle? STOP, break it down, fan out.

## Development ≠ Production

- **Local first.** Test locally before CI. Never push to CI "to see if it passes".
- **No Docker for dev.** Docker is a deployment tool. Run apps natively with hot reload; containerize only for deployment.
- **Mock external deps.** Always mock APIs/DBs/services with fake data during dev — it's the efficient path, not wasted time.
- **Isolated per-module tests** that run WITHOUT launching the full app (e.g. test one module file directly).
- **Honor `INVARIANTS.md`.** If present, verify every item is preserved before any refactor/rewrite.

## Session Discipline

- **Never drop a requirement** stated earlier in the session — it stays ACTIVE until contradicted. Re-check the whole request stack before delivering. "I told you" / "I already said" = you failed.
- **Never remove working code during refactors.** Default is PRESERVE. Only remove what was explicitly requested. Confirm before deleting >10 lines of logic. When migrating, verify the destination has EVERYTHING the source had before deleting. "It was working before" → diff and revert the regression.
- **Match specs/screenshots EXACTLY.** Pixel-by-pixel; use the exact layout/color/spacing values given. "Copy from X" = literally copy, don't recreate. Visually verify before delivering.
- **Don't over-engineer.** Simple request → simple solution. No new deps/architectures unless asked. Edit existing files over creating new ones. "Just do X" = ONE focused change.
- **Copy means COPY.** "Copy" / "as-is" / "verbatim" / "exactly" = zero modifications.
- **Update tests in the same change as the code** they cover; verify existing tests still pass.
- **Unblock yourself.** When a prerequisite is needed (app not running, tool not installed), do it yourself; only ask for credentials, physical access, or decisions you can't make.
- **Print vs run.** "Give me the command" = print it, don't execute.
- **Always include the PR link.** When finishing work on a pull request or writing final/status text about a PR, include the PR URL so the user can click through and inspect it.
- **Check format preference.** When the user asks for a "check", prefer answers with ✅ and ❌ markers because they are easier for the user to scan.

## Git History — linear only

- **No merge commits.** The user hates merge commits. Integrate branches with rebase, fast-forward, or cherry-pick only.
- Before pushing, verify the branch history is linear. If a merge commit would be required, stop and rebase or ask before proceeding.
- Never run `git merge` for branch integration unless the user explicitly asks for a merge commit.

# Progress Reporting

For non-trivial work, give honest `Progress: NN/100` updates at meaningful milestones and roughly every 30 seconds while active.

The percentage is a current estimate of user-visible completion, not a plan item, commitment, or substitute for verification.

Each progress update should briefly say what is done, what is happening now, and what remains or blocks completion.

# Subagent Delegation (Mandatory)

**Default stance: delegate first.** The parent agent orchestrates; subagents execute. Waiting for the user to say "use subagent" is a failure mode.

## Hard requirement

When **any** trigger below matches, you **MUST** launch one or more `Task` subagents **in the same turn** (parallel `Task` calls in one message). Do not "start inline and delegate later."

Announce briefly: *"Spawning N subagents: …"* then dispatch.

## Mandatory triggers (if any match → delegate)

| Trigger | Action |
|--------|--------|
| **2+ independent tracks** | Parallel subagents (e.g. SSH/logs + code search + docs/API) |
| **Unknown scope exploration** | `generalPurpose` subagent to map the area; parent waits for digest |
| **Infra / deploy / SSL / routing** | One subagent on remote logs (SSH), one on repo/config — parallel |
| **Multi-file feature or refactor** | Subagent per coherent slice (backend / frontend / CI) when ≥3 files or 2 domains |
| **Review request** | `bugbot` + `security-review` in parallel on branch diff (readonly) |
| **User asks for speed** | Parallelize everything that does not depend on the same output |
| **>2 exploratory tool rounds** before a user-facing answer | Stop; delegate the exploration |
| **Reading >250KB** of source | Delegate reads + summary |
| **Long-running shell** (tests, build, deploy) | Background subagent or parallel agent while parent continues |

## Do NOT delegate

- Single-file, single-step edits with known path
- One command whose output you need immediately in the next line
- User explicitly says "don't use subagents" or "do it yourself inline"

## Subagent prompt contract

Every `Task` prompt **must** include:

```
MODE: SUBAGENT          ← read-only research
MODE: SUBAGENT READ-WRITE   ← only when subagent may edit/run deploy commands
GOAL: …
CONTEXT: …
SCOPE: …
RETURN: … (exact digest format expected back)
```

Parent retains accountability: synthesize subagent digests; never paste raw traces.

## Parallelism rules

- Independent work → **one message, multiple `Task` calls**
- Never serialize subagents that could run together
- Prefer `run_in_background: true` for long investigations; parent continues other work

## Anti-shyness checklist (before answering)

1. Could this be split into 2+ independent investigations? → **Yes = delegate now**
2. Am I about to run a 3rd search/read hop? → **Delegate the hunt**
3. Is there SSH + local code + external API? → **3 parallel subagents**

If you skipped delegation and any trigger matched, **stop and delegate** before continuing.

# Telegraphic Brevity (HARD RULE)

Default voice for ALL prose output. Not optional. Meaning over grammar.

## Core
Lead with the answer. Details after, only if they change what the user does next. One idea per line. Fragments over sentences. Bullets/tables over paragraphs. Cut every word whose removal leaves meaning intact.

## Enforce
- Drop throat-clearing: "I'll now", "let me", "it looks like", "as you can see", "in order to", "please note", "I think", "essentially", hedges.
- Drop articles/auxiliaries when meaning survives: "the", "a", "is/are", "that".
- No restating the question. No preamble. No wrap-up pleasantries ("hope this helps", "let me know").
- Prefer `✅`/`❌`, tables, lists for anything comparative or scannable.

## Before → After (calibrate to this)
- ❌ "I went ahead and checked the logs, and it looks like the issue is that the port is already in use."
  ✅ "Cause: port already in use."
- ❌ "Let me know if you'd like me to also update the tests."
  ✅ "Tests not updated — say if wanted."
- ❌ "It seems that the build is currently passing."
  ✅ "Build passing."

## Never sacrifice (correctness > brevity)
- Exact paths, commands, code, identifiers, numbers — verbatim.
- The `VERIFIED:` / `UNVERIFIED:` line + what was run/observed.
- Warnings, blockers, safety/authorization caveats.
- Code itself — telegraph the prose around code, never the code.

## Exceptions — DON'T telegraph when prose IS the deliverable
- User explicitly asks to explain/teach/reason out loud, or wants a walkthrough.
- User-facing copy: commit messages, PR/issue bodies, docs, READMEs, emails, release notes.
- A subtle decision where the reasoning is the value, not the conclusion.
In these, write normally. Brevity rule governs working chatter, not authored content.

## Self-check before sending
If a line restates the question, hedges, or could be deleted without losing a fact → delete it. If output is one unbroken paragraph and contains ≥2 facts → convert to list. Short ≠ vague: stripped words, never stripped facts.

# Tech Stack Conventions

## Package Manager — bun only
- ALWAYS use `bun` / `bunx`. NEVER npm, yarn, pnpm, or npx — applies to subagents and CI configs too.
- Install bun via `curl -fsSL https://bun.sh/install | bash`. NEVER `npm install -g bun`. In Docker, use the `oven/bun` image directly.
- Lockfile is `bun.lock` (not the legacy `bun.lockb`).

## Dev server & build — NEVER run them yourself (HARD RULE)
- NEVER run `bun run dev` / `bun run build` — nor `dev:*`, `preview`, `next dev`/`next build`, `vite dev`/`vite build`, or any equivalent. The dev server and build are managed **externally**: a file watcher with hot-reload and/or a concurrently-running agent already owns the dev server.
- Spawning a second dev server makes two HMR instances fight over the same port: the browser's HMR websocket connects, gets bumped, reconnects, and vite reloads the page on every reconnect → **infinite page reload with NO console error** — it looks like an app bug but is pure infrastructure. This has burned long debugging sessions.
- To verify changes: assume a dev server is already running and hit the existing port (`curl` / agent-browser). If nothing is serving, ask the user to start it or confirm the port — do NOT start one yourself.
- "Give me the command" = print it, don't run it.

## TypeScript
- TypeScript everywhere, except config files that explicitly require JS.
- Define functions as `const` arrow functions with implicit returns.
- Always use path aliases.

## Next.js
- App Router. API handlers are `route.ts` (GET/POST exports).
- Always run with turbopack.
- Component structure (mandatory):
  - JSX files contain **view logic only**.
  - Data fetching, state, and handlers live in custom hooks or separate modules.
  - Split large components into minimal per-file view components (e.g. a 2-column layout = 2 separate column components, each in its own file).
  - One `useForm` / schema definition per file.
  - Minimize inline JSX logic — delegate to hooks/helpers.

## Styling — Tailwind v4 only
- Use `@import "tailwindcss"` in CSS.
- NO `tailwind.config.js` / `tailwind.config.ts`.
- NO `@tailwind base/components/utilities`.
- NEVER install autoprefixer.
- Config is CSS-based via `@theme`.
- After setup, render a page and verify styles actually apply.

## State & Data
- Global state: `@legendapp/state@3.0.0`.
- Data fetching: `@tanstack/react-query` with controller-style hooks (destructure and rename, e.g. `isPending`, `mutateAsync`).
- API calls: `axios` (unless a first-party frontend SDK exists).
- Dates: `dayjs` — never `date-fns`.

## Forms
- `react-hook-form` + `@hookform/resolvers/zod`.
- Provide `defaultValues` at the top of the component (fake data when `isDev`).

## Electron + Bun hot-reload
- Setup uses `electron-vite` + `electron-reloader` + bun; rebuilds are handled externally.
- NEVER manually run `bun run dev` / `bun run build` (or `dev:desktop`, `preview:desktop`).
- Only edit source files — hot reload detects changes and rebuilds main/preload/renderer.

# Persist Generated Plans to File and Clipboard

Whenever you generate a plan, roadmap, todo list, implementation outline, or decision tree for the user — whether in Codex, Claude Code, Devin, or any other AI coding agent — you MUST persist the final, formatted plan in two places:

1. A markdown file under `~/.plans/`
2. The user's system clipboard

## What to Persist

- Any multi-step plan, task list, roadmap, or structured implementation outline the user explicitly asks for or that you produce unprompted as part of the workflow.
- The final, cleaned-up version of the plan (not draft fragments, not internal scratch notes).
- If the plan is already written to a file elsewhere, still copy it to `~/.plans/` and copy the contents to the clipboard.

## File Naming

Write each plan to `~/.plans/` using a timestamped filename:

```
~/.plans/YYYY-MM-DD_HH-MM-SLUG.md
```

Where `SLUG` is a short, kebab-case summary of the plan (e.g., `refactor-auth-service`, `add-stripe-billing`, `fix-docker-network`).

Example: `~/.plans/2026-06-27_14-35-add-stripe-billing.md`

Ensure the `~/.plans/` directory exists before writing.

## How to Persist

### File

Write the final plan text to the timestamped markdown file. Use a shell command or the file tools available in your environment.

### Clipboard

After writing the file, copy the plan text to the system clipboard:

- **macOS**: `cat "$file" | pbcopy`
- **Linux (X11)**: `cat "$file" | xclip -selection clipboard`
- **Linux (Wayland)**: `cat "$file" | wl-copy`
- **Windows**: `cat "$file" | clip.exe` or PowerShell `Get-Content "$file" | Set-Clipboard`

## When to Persist

- Immediately after finalizing the plan and before asking the user to review it.
- If the plan is updated later, overwrite the same file or write a new revision and copy the updated version again.

## Confirmation

After persisting, tell the user once:

**"Plan saved to `~/.plans/<filename>.md` and copied to clipboard."**

## Why

- The file keeps a durable, timestamped history of every plan.
- The clipboard lets the user paste the plan into notes, tickets, or other tools immediately.
- The saved files enable later commands like "implement the last plan" to reuse the most recent plan.

# Implement the Last Plan

When the user asks to "implement the last plan", "do the last plan", "execute the last plan", "run the latest plan", or any similar phrasing, you MUST load the most recently modified `.md` file in `~/.plans/` and use it as the specification for the current task.

## How to Find the Last Plan

1. List all `*.md` files in `~/.plans/`.
2. Pick the one with the most recent modification time (last modified file).
3. If the directory does not exist or is empty, stop and tell the user: "No plans found in `~/.plans/`. Please generate a plan first."

Use a shell command like:

- **macOS/Linux**: `ls -t ~/.plans/*.md | head -n 1`
- **Cross-platform**: `find ~/.plans -maxdepth 1 -name "*.md" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-`

## How to Use the Last Plan

- Read the full contents of the selected file.
- Treat it as the authoritative spec/roadmap for the current task.
- Follow its steps, priorities, and acceptance criteria exactly.
- If the plan is ambiguous or outdated, read it first, then ask the user a focused clarifying question before starting implementation.
- Do NOT ignore the plan or generate a new plan unless the user explicitly asks for a different plan.

## Confirmation

After reading the last plan, tell the user:

**"Loaded last plan from `~/.plans/<filename>.md`. Implementing now."**

## Why

This lets the user generate a plan in one session (or in another tool) and then return later to execute it without re-pasting the entire plan.

# Tooling Conventions

## RTK (Rust Token Killer) — prefix every shell command

ALWAYS prefix shell commands with `rtk`. It applies a token-saving filter when it has one and passes unknown commands through unchanged, so it is always safe.

- Use `rtk` even inside `&&` chains: `rtk git add && rtk git commit -m "msg" && rtk git push`.
- Substitutions:
  - `ls`/`tree` → `rtk ls <path>`
  - `cat`/`head`/`tail` → use plain `cat`/`head`/`tail` for session-init and hook-restricted bootstrap docs; otherwise `rtk read <file>` (`-l aggressive` for code)
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

Skills are CENTRALIZED. The single source of truth is **`~/.agent-config/skills/`** — author and edit every shared skill THERE, once.

- After creating/editing a skill, run **`./sync-skills.sh`** (called automatically by `./build.sh`): it fans the canonical set out to `~/.codex/skills`, `~/.cursor/skills`, `~/.gemini/skills`, `~/.devin/skills`, `~/.claude/skills`, and re-vaults via chezmoi so genesis + exodus get it too.
- The fanout is ADDITIVE — each tool keeps its own tool-specific skills (e.g. codex `codex-primary-runtime`/`harness`, cursor `gitnexus-*`). Those tool-specific ones may be edited in place.
- NEVER hand-edit a shared skill inside `~/.codex|.cursor|.gemini|.devin|.claude/skills` — it will be overwritten on the next sync. Edit the canonical `~/.agent-config/skills/<name>/SKILL.md`.
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

# Parallel Subagents — Use Proactively (HARD RULE)

Default to spawning parallel subagents/sessions for independent work. Do NOT wait for the user to explicitly ask ("use subagents", "parallelize this", "fan out") — that instruction should never be required. If you find yourself about to do 2+ independent things serially, stop and parallelize first.

## When to parallelize (proactively, unannounced)

- **Multi-file/multi-area investigation**: understanding a codebase, tracing a bug across modules, auditing a directory tree — split by file/module/area and run concurrently instead of reading one-by-one.
- **Independent research questions**: any time a task decomposes into 2+ sub-questions whose answers don't depend on each other (compare options, check multiple services/configs, look up multiple docs).
- **Debugging**: never enter a serial try → wait → fail → retry loop. Decompose into independent hypotheses/pieces and investigate them concurrently. Hitting the same issue more than twice in a row without decomposing is a violation.
- **Reviews/audits**: dimension-by-dimension (correctness, security, perf, tests, docs) — each dimension is an independent subagent, not a single serial pass.
- **Any list of N similar independent items** (N files to migrate, N services to check, N endpoints to test) — one subagent per item, not a loop.

## When NOT to parallelize

- A single, small, tightly-coupled task with no independent sub-parts.
- Steps that genuinely depend on each other's output (must stay serial).
- Trivial one-shot lookups where spawning overhead exceeds the work itself.

## Enforcement

- Before starting multi-step work, ask yourself: "does this decompose into independent pieces?" If yes, fan out by default.
- Never ask the user for permission to parallelize — just do it, same as any other execution-strategy decision.
- Report back as if the work were synthesized normally; don't over-narrate the orchestration mechanics unless asked.

# CMUX Transport Only

When the user asks to coordinate Codex, Devin, Claude Code, or Cursor CLI, use
the shared `cmux-agent-bridge` skill. The canonical skill is in
`.agent-config/skills/cmux-agent-bridge` and synced to each tool's local skill
directory.

## Required Pattern

- Use CMUX live terminal panes as the transport target.
- Do not use ACPX, `codex exec`, `devin -p`, or any headless agent subprocess for this bridge.
- Do not start or configure a protocol server for agent-to-agent handoffs.
- From an existing CMUX pane, run the setup script from the local tool skill; it detects `CMUX_WORKSPACE_ID` and reuses the current workspace.
- If no CMUX workspace exists, the setup script creates one for the current project.
- For one-off handoffs, use `cmux-agent-send` directly.
- For automated review loops, use `cmux-agent-send --queue`; `cmux-agent-triggerd` delivers queued handoffs into the live CMUX terminal when the target is ready.
- Before ending coordinated work, send a `final_handoff` with `cmux-agent-send`; use `--queue` when the next agent should receive it automatically.

## Setup Commands

Use the command for the current tool:

```bash
# Codex
/Users/livio/.codex/skills/cmux-agent-bridge/scripts/setup-cmux-agent-bridge.sh

# Claude Code
/Users/livio/.claude/skills/cmux-agent-bridge/scripts/setup-cmux-agent-bridge.sh

# Cursor CLI
/Users/livio/.cursor/skills/cmux-agent-bridge/scripts/setup-cmux-agent-bridge.sh

# Devin
/Users/livio/.devin/skills/cmux-agent-bridge/scripts/setup-cmux-agent-bridge.sh
```

## Agent IDs

Use stable agent IDs so messages route consistently:

- Short aliases: `codex`, `devin`
- Codex reviewer/planner: `codex-reviewer`
- Devin implementer: `devin-implementer`
- Claude Code participant: `claude-code-agent`
- Cursor CLI participant: `cursor-agent`

When Claude Code or Cursor CLI is replacing Codex as the reviewer/planner,
still send implementation handoffs to `devin-implementer`. When sending material
back to Codex, use `codex-reviewer`.

## Final Handoff Examples

Claude Code to Devin:

```bash
cmux-agent-send --queue \
  --from claude-code-agent \
  --to devin-implementer \
  --type final_handoff \
  "Final handoff from Claude Code: <summary, files changed, validation, next action>"
```

Cursor CLI to Devin:

```bash
cmux-agent-send --queue \
  --from cursor-agent \
  --to devin-implementer \
  --type final_handoff \
  "Final handoff from Cursor CLI: <summary, files changed, validation, next action>"
```

Devin to Codex:

```bash
cmux-agent-send --queue \
  --from devin-implementer \
  --to codex-reviewer \
  --type final_handoff \
  "Final handoff from Devin: <summary, files changed, validation, blockers>"
```

# Interactive Commands Run in a New Pane (HARD RULE)

The agent's own terminal/pane must NEVER block. Anything interactive, long-running-with-UI, or requiring a TTY runs in a **freshly spawned pane to the right or on top** — never inline in the agent's execution flow.

## What MUST go to a new pane

- TUIs and pagers: `vim`, `nano`, `htop`, `top`, `less`, `tig`, `lazygit`, `k9s`, menuconfig-style installers
- Watch/serve modes: `--watch`, `tail -f`, dev servers, log followers, `docker logs -f`, `kubectl logs -f`
- REPLs and shells: `python`, `node`, `bun repl`, `psql`, `redis-cli`, `ssh` interactive sessions
- Anything that prompts mid-run: `npm init`-style wizards, `gh auth login`, OAuth device flows, password prompts
- Any command expected to run indefinitely or until manually stopped

## How

- In Warp/CMUX/RMUX contexts: spawn a split pane (prefer right, else top) and send the command there:
  - `rmux split-window -h` + `rmux send-keys "<cmd>" Enter` (or the CMUX equivalent)
  - Warp native: split pane action, then inject the command
- The agent continues working in its own pane immediately; poll the side pane's output (`rmux capture-pane` / logs) if the result matters.
- If no multiplexer/pane API is available: run non-interactively instead (flags like `--no-input`, `--yes`, `| cat`, `GIT_PAGER=cat`) or run detached (`run_in_background`, `nohup`) — but NEVER launch a blocking interactive process in the agent's own flow.

## Why

A blocked agent pane means the whole loop stalls on a prompt nobody will answer. Side panes keep interactivity available to the human while the agent stays unblocked — this is the smart default, always.

# Browser Automation: agent-browser ONLY (HARD RULE)

`agent-browser` (at `/opt/homebrew/bin/agent-browser`) is the ONLY tool for browser automation. Never drive a browser any other way — no raw Playwright/Puppeteer scripts spawning their own Chromium, no local Chrome/Chromium launches, no ad-hoc Selenium.

## Engine selection

1. **Default: remote browserless.** Route sessions through the browserless instance (`https://browserless.liviogama.com?token=<token>` — token from env/password manager, never committed):
   ```bash
   agent-browser --session bl connect "https://browserless.liviogama.com?token=$BROWSERLESS_TOKEN"
   agent-browser --session bl open <url> / screenshot / console / network
   ```
2. **Local loops: headless Lightpanda.** For fast local smoke checks, DOM assertions, console/network inspection, and regression loops when remote round-trips are wasteful:
   ```bash
   agent-browser --engine lightpanda --session main <cmd>
   ```
3. **Visual judgment needed:** open the default browser onto the remote Chrome instance (`open "$CHROME_REMOTE_URL"`, credentials from the password manager). Local headed Brave only when explicitly requested.

## Session discipline

- Reuse named sessions (`--session main`, `--session bl`) — NEVER spawn a new browser per call.
- Parallelize with additional isolated `--session <name>` sessions; use `--json` for structured `{success, data, error}` output.
- When debugging, always capture `console` + `network`, not just screenshots.
- Electron apps: connect to the running renderer via agent-browser's CDP/Electron path — never launch a second browser.

## Why

One tool = predictable sessions, token-cheap output, no zombie Chromium fleets. Browserless keeps heavy rendering off the Mac (consistent with the VPS-offload rule); Lightpanda keeps local checks fast and headless.

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

# Platform Conventions

## macOS app builds — sign ONCE, never re-prompt for password/permissions (HARD RULE)

When building/compiling a macOS app, the user must NOT be re-asked for their password or to re-grant macOS (TCC) permissions (Screen Recording, Accessibility, Camera, Files, etc.) on every rebuild. macOS keys those grants to the app's **bundle id + code-signing designated requirement** — if either changes between builds, every grant resets and the user is prompted again. So:

- **Use a STABLE signing identity and a STABLE bundle id across all builds.** Never let them vary build-to-build (no random/timestamped bundle ids, no switching between ad-hoc and a cert).
- **Pick one signing mode and keep it:**
  - Dev/local: stable **ad-hoc** signature — `codesign --force --deep --options runtime --sign - <App>.app` (the `-` identity is stable as long as you always use it). OR
  - A persistent self-signed / Developer ID cert in the login keychain, referenced by the SAME `CODE_SIGN_IDENTITY` every time.
- **Keep the same `Info.plist` bundle id** (`CFBundleIdentifier`) and the same team/identity — this is what TCC remembers.
- **Don't strip/replace entitlements between builds** in a way that changes the designated requirement.
- For keychain access prompts: sign stably so the keychain ACL trusts the same binary identity instead of treating each rebuild as a new app.
- After the FIRST build, the user grants permissions once; every subsequent rebuild must reuse identity+bundle-id so macOS recognizes it as the same app and stays silent.

**Make this hard to break:** bake the stable identity + bundle id into the build script/Xcode config (not passed ad-hoc on the command line), and verify with `codesign -dv --verbose=4 <App>.app` that the identity and bundle id are unchanged before declaring a build done.

# ACP/acpx/codex-acp Auto-Update to acp-toolbox Skill

When fixing, debugging, or learning something related to **ACP (Agent Client Protocol)**, **acpx**, or **codex-acp**:

**ALWAYS update the acp-toolbox skill** to document the fix or learning.

This is not optional housekeeping. It is part of finishing the fix. Do it before the final response, after the behavior has been verified.

## Workflow

1. **Fix the issue** in the codebase as normal
2. **Update acp-toolbox skill**:
   - Edit: `.agent-config/skills/acp-toolbox/SKILL.md`
   - Add the fix, gotcha, or learning to the appropriate section
   - If it's Codex-specific, add to `references/shell/09-codex-special-handling.md`
   - If it's a general pattern, add to the relevant section (TypeScript, Shell, General Patterns, or Agent-Specific Quirks)
3. **Commit the skill update**:
   ```bash
   cd ~/agent-config
   git add .agent-config/skills/acp-toolbox
   git commit -m "docs: [what you learned/fix] in acp-toolbox"
   git push
   ```
4. **Sync to all tools**:
   ```bash
   ./sync-skills.sh
   ```

## What Triggers This Rule

Update acp-toolbox when you:
- Fix an ACP stdio framing issue
- Debug a streaming problem (SSE, ndjson, JSON-RPC)
- Resolve a permission round-trip issue
- Fix subprocess lifecycle (orphan reaping, process groups)
- Learn about agent-specific quirks (Codex, Claude, Cursor, Gemini, etc.)
- Discover a gotcha with session management
- Fix timeout or cancellation issues
- Learn about authentication (OAuth vs API keys)
- Debug model selection or capability issues
- Discover the correct ACP package or binary for an agent
- Fix Codex ACP auth, model selection, sandbox, or permission mode behavior

## Codex ACP Defaults Learned the Hard Way

- Use `@zed-industries/codex-acp` for Codex ACP. Do **not** use `@agentclientprotocol/codex-acp`.
- ChatGPT subscription auth is valid via `codex login` / `~/.codex/auth.json`; API-key mode may use `CODEX_API_KEY` or `OPENAI_API_KEY`.
- Do not assume `session/set_model` works. Zed `codex-acp` may expose model/reasoning through `session/new.configOptions`; use prompt-level model/reasoning or `session/set_config_option` where appropriate.
- Trusted direct-write harnesses must call `session/set_mode` with `modeId: "full-access"` before `session/prompt`.
- A write failure mentioning a read-only sandbox is usually a session mode/config problem, not an authentication problem.

## Why This Matters

- acp-toolbox is the **central knowledge base** for all ACP patterns
- Every gotcha cost someone real debugging time
- Documenting it prevents future debugging sessions
- The skill is used across all tools (Codex, Claude Code, Cursor, Gemini, Devin)
- Centralized documentation ensures consistency

## Example

❌ **Wrong:**
```bash
# Fix the bug in code, move on
# The next person hits the same issue and spends 2 hours debugging
```

✅ **Correct:**
```bash
# Fix the bug in code
# Then update acp-toolbox
cd ~/agent-config
vim .agent-config/skills/acp-toolbox/SKILL.md
# Add: "Gotcha: ACP notifications have no 'id' field, use 'method' to detect type"
git add .agent-config/skills/acp-toolbox && git commit -m "docs: add notification id gotcha" && git push
./sync-skills.sh
```

## Reference: acp-toolbox Update Section

See the "Applying Session Learnings" section in acp-toolbox for the full update workflow.

# Debug Real Artifacts First

When debugging a flow that already produced logs or artifacts, read those real files before relying on code inspection, synthetic fixtures, or assumptions.

For `omni start`, Slack notifications, Intent Map intake, task creation, or workspace launch behavior, inspect the failing project's real artifacts first:

- `.omni/omni.log`
- `.omni/requirements.md`
- `.omni/source-assessment.json`
- `.omni/source-refinement.md`
- `.omni-ee/state.yaml` when present

Regression tests must use the artifact shape observed in the failing project. Do not replace it with simplified invented Markdown.

If the correct project is unclear, ask the user which project/log directory to inspect before proceeding.

# Editing Global Rules and Skills

When the user asks to "add to AGENTS.md and CLAUDE.md global" or "add a skill" or similar phrasing:

**NEVER edit the generated files in the tool directories** (`~/.claude/CLAUDE.md`, `~/.claude/AGENTS.md`, `~/.codex/AGENTS.md`, `~/.codex/skills/`, `~/.claude/skills/`, etc.).

Instead, edit the source and let it pass through to the tools.

## Rules Workflow

1. **Add the rule to the source**: Create or edit a file in `~/.agent-config/rules/`
2. **Regenerate configs**: Run `./build.sh` (this syncs the rule to all tool directories)
3. **Verify deployment**: Check that the rule appears in the generated files
4. **Commit and push**: `cd ~/agent-config && git add .agent-config/AGENTS.md rules/ build.sh sync-skills.sh rulesync.jsonc && git commit -m "..." && git push`

## Skills Workflow

1. **Add the skill to the source**: Create or edit in `~/.agent-config/skills/<skill-name>/SKILL.md`
2. **Sync to all tools**: Run `./sync-skills.sh` (fans out to `~/.codex/skills`, `~/.cursor/skills`, `~/.gemini/skills`, `~/.devin/skills`, `~/.claude/skills`)
3. **Commit changes to agent-config repo if needed**

## Why This Matters

- The tool directories (`~/.claude/`, `~/.codex/`, etc.) contain **generated files**
- Editing them directly will be **overwritten** the next time `./build.sh` or `./sync-skills.sh` runs
- The source of truth for rules is `~/.agent-config/rules/*.md`
- The source of truth for skills is `~/.agent-config/skills/`
- The build script fans out rules to all tools automatically
- The sync script fans out skills to all tools automatically

## Examples

❌ **Wrong (Rules):**
```bash
# Editing the generated file in the tool directory
vim ~/.claude/CLAUDE.md
vim ~/.codex/AGENTS.md
```

✅ **Correct (Rules):**
```bash
# Edit the source rule in agent-config
vim ~/.agent-config/rules/my-new-rule.md
# Regenerate and sync to all tools
./build.sh
# Commit
git add .agent-config/AGENTS.md rules/ build.sh sync-skills.sh rulesync.jsonc && git commit -m "add: my new rule" && git push
```

❌ **Wrong (Skills):**
```bash
# Editing the skill in the tool directory
vim ~/.codex/skills/my-skill/SKILL.md
```

✅ **Correct (Skills):**
```bash
# Edit the source skill
vim ~/.agent-config/skills/my-skill/SKILL.md
# Sync to all tools
./sync-skills.sh
```

## Tool-Specific Rules

If the rule is specific to a single tool, add it to that tool's rules directory:
- Codex: `.codex/rules/` or `.codex/memories/`
- Claude Code: `.claude/rules/`
- Devin: `.devin/rules/`

Then run `./build.sh` to deploy.

# Force Internet Search on Triple Failure

**HARD RULE**: When Devin fails the same operation three times in a row, it MUST systematically search the internet before attempting a fourth retry.

## Trigger Condition

An operation is considered "failed" when:
- Command execution returns non-zero exit code
- API call returns error/failure status
- Code compilation/build fails
- Test execution fails
- Tool operation fails
- Any operation that doesn't produce the expected result

**Three consecutive failures** of the same operation (or closely related operations on the same component) triggers this rule.

## Required Action

After the third failure, BEFORE attempting a fourth retry:

1. **Stop and acknowledge the pattern**: "This operation has failed 3 times. Forcing internet search."

2. **Systematically search the internet**:
   - Use `web_search` tool with specific, technical queries
   - Search for the exact error message
   - Search for the library/framework/tool documentation
   - Search for similar issues on GitHub/Stack Overflow
   - Search for the specific API/method/function being used

3. **Review search results**:
   - Read the most relevant documentation
   - Check for version-specific issues
   - Look for configuration requirements
   - Identify common pitfalls

4. **Apply findings**:
   - Update approach based on documentation
   - Fix configuration issues
   - Use correct API parameters
   - Apply documented workarounds

5. **Then retry** with the updated approach

## What Counts as "Same Operation"

- Same command with same parameters
- Same API call with same arguments
- Same function/method invocation
- Same build/compile target
- Same test suite execution
- Same tool operation on same target

## Examples

❌ **Wrong** (blind retry loop):
```
Attempt 1: npm install → fails
Attempt 2: npm install → fails
Attempt 3: npm install → fails
Attempt 4: npm install → fails (should have searched after attempt 3)
```

✅ **Correct** (forced search after 3 failures):
```
Attempt 1: npm install → fails
Attempt 2: npm install → fails
Attempt 3: npm install → fails
→ "This operation has failed 3 times. Forcing internet search."
→ web_search "npm install fails permission denied"
→ web_search "npm install troubleshooting"
→ Read npm docs on permissions
→ Apply fix: use --unsafe-perm flag or fix directory permissions
Attempt 4: npm install --unsafe-perm → succeeds
```

## Why This Rule

- Blind retry loops waste enormous time
- Three failures indicate a fundamental misunderstanding or missing information
- Current training data may be outdated for fast-moving libraries/tools
- Systematic documentation review often reveals the correct approach
- Prevents infinite retry cycles on unsolvable problems
- Forces explicit acknowledgment of stuck state

## Exception

If the operation requires credentials, physical access, or decisions that cannot be made by the agent, the rule does not apply — state the blocker explicitly instead of searching.

# Global Content Workflow

When the user asks to "add to AGENTS.md and CLAUDE.md global" or "add a skill" or similar phrasing:

**NEVER edit the generated files in the tool directories** (`~/.claude/CLAUDE.md`, `~/.claude/AGENTS.md`, `~/.codex/AGENTS.md`, `~/.codex/skills/`, `~/.claude/skills/`, etc.).

Instead, edit the source and let it pass through to the tools.

## Rules Workflow

1. **Add the rule to the source**: Create or edit a file in `~/.agent-config/rules/`
2. **Regenerate configs**: Run `./build.sh` (this syncs the rule to all tool directories)
3. **Verify deployment**: Check that the rule appears in the generated files
4. **Commit and push**: `cd ~/agent-config && git add .agent-config/AGENTS.md rules/ build.sh sync-skills.sh rulesync.jsonc && git commit -m "..." && git push`

## Skills Workflow

1. **Add the skill to the source**: Create or edit in `~/.agent-config/skills/<skill-name>/SKILL.md`
2. **Sync to all tools**: Run `./sync-skills.sh` (fans out to `~/.codex/skills`, `~/.cursor/skills`, `~/.gemini/skills`, `~/.devin/skills`, `~/.claude/skills`)
3. **Commit changes to agent-config repo if needed**

## Why This Matters

- The tool directories (`~/.claude/`, `~/.codex/`, etc.) contain **generated files**
- Editing them directly will be **overwritten** the next time `./build.sh` or `./sync-skills.sh` runs
- The source of truth for rules is `~/.agent-config/rules/*.md`
- The source of truth for skills is `~/.agent-config/skills/`
- The build script fans out rules to all tools automatically
- The sync script fans out skills to all tools automatically

## Examples

❌ **Wrong (Rules):**
```bash
# Editing the generated file in the tool directory
vim ~/.claude/CLAUDE.md
vim ~/.codex/AGENTS.md
```

✅ **Correct (Rules):**
```bash
# Edit the source rule in agent-config
vim ~/.agent-config/rules/my-new-rule.md
# Regenerate and sync to all tools
./build.sh
# Commit
cd ~/agent-config && git add .agent-config/AGENTS.md rules/ build.sh sync-skills.sh rulesync.jsonc && git commit -m "add: my new rule" && git push
```

❌ **Wrong (Skills):**
```bash
# Editing the skill in the tool directory
vim ~/.codex/skills/my-skill/SKILL.md
```

✅ **Correct (Skills):**
```bash
# Edit the source skill
vim ~/.agent-config/skills/my-skill/SKILL.md
# Sync to all tools
./sync-skills.sh
```

## Tool-Specific Rules

If the rule is specific to a single tool, add it to that tool's rules directory:
- Codex: `.codex/rules/` or `.codex/memories/`
- Claude Code: `.claude/rules/`
- Devin: `.devin/rules/`

Then run `./build.sh` to deploy.

# Inmo Ship Fast Sync Rules (HARD RULE)

The `inmo` repo (`github.com/ShipFastAI/inmo`) contains `apps/ship-fast-agent`, which is a fork of `omni/apps/omni-agent` (`github.com/omni3ai/omni`). When syncing changes from omni to inmo, follow these rules strictly.

## Server Isolation (HARD RULE)

- **`ssh o` = 75.119.153.19 = omni server** (Dokploy at `dokploy.omni3.ai`, app at `agent.omni3.ai`)
- **`ssh exodus` = 178.105.58.38 = Ship Fast server** (Dokploy at `dokploy.devliv.io`, app at `agent.ship-fast.ai`)
- **NEVER deploy Ship Fast infrastructure on `ssh o`.** Always deploy on `ssh exodus`.
- **NEVER deploy Omni infrastructure on `ssh exodus`.** Always deploy on `ssh o`.
- Before deploying anything, verify the target server with `ssh <alias> hostname` and confirm it matches the expected IP.

## Sync Workflow (HARD RULE)

When syncing commits from `omni/apps/omni-agent` to `inmo/apps/ship-fast-agent`:

1. **Check the source branch first.** Always verify which branch you're syncing from:
   ```bash
   cd ~/Documents/omni && git branch --show-current
   cd ~/Documents/omni && git log --oneline -5
   ```
   Do NOT assume you're on `main`. The latest changes may be on a feature branch.

2. **Identify missing commits:**
   ```bash
   cd ~/Documents/inmo && git log --oneline -5
   ```
   Compare with omni. Cherry-pick or merge missing commits.

3. **Rename omni references during sync.** After importing code:
   - `omni-agent` → `ship-fast-agent` (in paths, package names, env vars)
   - `omni_agent` → `ship_fast_agent` (in Python module names, imports)
   - `omni_review` → `ship_fast_review` (file names, imports)
   - `omni_events` → `ship_fast_events` (file names, imports)
   - `omni-agent-bot` → `ship-fast-agent-bot` (pyproject.toml name, uv.lock)
   - `agent.omni3.ai` → `agent.ship-fast.ai` (URLs in tests, config)
   - `db-agent.omni3.ai` → `db-agent.ship-fast.ai` (PocketBase URL)

4. **Regenerate uv.lock after renaming.** If `pyproject.toml` name changes:
   ```bash
   cd apps/ship-fast-agent && uv lock
   ```
   The `uv.lock` file contains the package name. A stale lockfile will fail with `Could not find root package`.

5. **Keep Slack channel settings.** The inmo fork uses:
   - `SLACK_CHANNEL_DEFAULT = "dev"` (channel ID `C0B8F69RQCB`)
   - Do NOT overwrite with omni's `test` or `-bot-dev` defaults.

6. **Keep PocketBase URL pointing to Ship Fast infra:**
   - `POCKETBASE_URL=https://db-agent.ship-fast.ai`
   - `POCKETBASE_ADMIN_EMAIL=hello@ship-fast.ai`
   - Do NOT use `http://pocketbase:8090` (omni's internal Docker network URL).

## Dokploy Deploy Rules (HARD RULE)

1. **Never overwrite env vars without reading them first.** Before calling `dokploy application save-environment`:
   ```bash
   # Read current env from the running container
   ssh exodus 'sudo docker inspect <container-name> --format "{{json .Config.Env}}"'
   ```
   Save the existing env to a backup file. Merge new vars into the existing set. Never replace the entire env block with only the new vars.

2. **Verify buildPath matches the app directory.** Check in Dokploy DB:
   ```bash
   ssh exodus 'sudo docker exec dokploy-postgres.* psql -U dokploy -d dokploy -c "SELECT \"buildPath\" FROM application WHERE \"applicationId\"='\''<id>\'';"'
   ```
   Must be `apps/ship-fast-agent`, not `apps/ship-fast` or `apps/omni-agent`.

3. **After deploy, verify the container has the new code:**
   ```bash
   ssh exodus 'sudo docker exec <container-name> ls /app/app/'
   ```
   Must include `review_settings.py`, `ship_fast_review.py`, `pocketbase_client.py`.

4. **After deploy, verify the UI serves the new code:**
   ```bash
   curl -sL https://agent.ship-fast.ai/ | grep -i "Gandalf Settings"
   ```
   Or use `agent-browser` to snapshot the page and confirm the settings panel renders.

## Build Failure Checklist

If the nixpacks build fails, check in this order:

1. **uv.lock stale?** → `cd apps/ship-fast-agent && uv lock` and commit
2. **bun binaries not in PATH?** → Ensure `export PATH="/root/.bun/bin:$PATH"` before `bun install -g` and use absolute paths for symlinks (`ln -sf /root/.bun/bin/acpx /usr/local/bin/acpx`)
3. **Deprecated packages?** → Use `@agentclientprotocol/codex-acp`, NOT `@zed-industries/codex-acp`
4. **Missing build-time env vars?** → The Dockerfile validates `GITHUB_WEBHOOK_SECRET`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `SESSION_SECRET` at build time. These come from the runtime env, not buildArgs.
5. **Wrong buildPath?** → Must be `apps/ship-fast-agent` in Dokploy DB.

## Git History Rules

- **No `omni-agent` references in commit messages.** Use `ship-fast-agent` instead.
- **No `omni` references in commit messages** when referring to the Ship Fast app.
- If rewriting history, force-push with `git push --force` (not `--force-with-lease` if remote has diverged).
- Always clean up filter-branch backup refs: `git for-each-ref --format='%(refname)' refs/original/ | xargs -n1 git update-ref -d`

# Omni Private Infrastructure

For live Omni infrastructure debugging, the Omni host SSH alias is `o`.

Use `ssh o` when locating the running Omni-Agent deployment that receives `OMNI_AGENT_URL` events.

Live Omni-Agent URL: `https://agent.omni3.ai`

Omni Dokploy URL: `https://dokploy.omni3.ai`

# Progress Reporting

For non-trivial work, give honest `Progress: NN/100` updates at meaningful milestones and roughly every 30 seconds while active.

The percentage is a current estimate of user-visible completion, not a plan item, commitment, or substitute for verification.

Each progress update should briefly say what is done, what is happening now, and what remains or blocks completion.

# Skill Update and Sync Pattern

When you create, edit, or fix a skill, you MUST sync it to all AI tools before declaring work complete.

## Workflow

1. **Create or edit the skill** in `~/.agent-config/skills/your-skill/SKILL.md`
2. **Commit the skill changes**:
   ```bash
   cd ~/agent-config
   git add .agent-config/skills/your-skill
   git commit -m "docs: update your-skill with [changes]"
   git push
   ```
3. **Sync to all tools**:
   ```bash
   ./sync-skills.sh
   ```
4. **Verify deployment** — the skill should now appear in all tool directories

## Why This Matters

- Skills are centralized in `~/.agent-config/skills/` but each tool needs its own copy
- The sync script fans out skills to Codex, Claude Code, Devin, Cursor, etc.
- Without syncing, your skill changes won't be available to other agents
- This ensures consistency across all AI coding tools

## Quick Reference

**Sync script location:** `~/agent-config/sync-skills.sh`  
**Canonical skills source:** `~/.agent-config/skills/`  
**Tool destinations:** `~/.codex/skills`, `~/.cursor/skills`, `~/.devin/skills`, `~/.claude/skills`, `~/.gemini/skills`

## One-Click Installation

You can install this rule directly via deeplink to enforce skill syncing:

[![Install Skill Sync Rule](https://img.shields.io/badge/Install_Skill_Sync_Rule-blue?style=for-the-badge)](agent-config://https://raw.githubusercontent.com/LivioGama/agent-config/main/.agent-config/rules/skill-sync-pattern.md)

# Skills Centralization

**Skills are centralized** in `~/.agent-config/skills/` — this is the single source of truth for all shared skills.

## Golden Rule

**NEVER edit skills directly in tool-specific skills directories** (e.g., `~/.codex/skills/`, `~/.claude/skills/`, `~/.devin/skills/`) — they will be overwritten on the next sync.

## Workflow

1. **Edit** skills in the canonical location: `~/.agent-config/skills/<skill-name>/SKILL.md`
2. **Sync** to all tools: `cd ~/agent-config && ./sync-skills.sh`
3. **Commit** changes to agent-config repo if needed

## What Gets Synced

The sync script fans out skills from `~/.agent-config/skills/` to:
- `~/.codex/skills/`
- `~/.cursor/skills/`
- `~/.gemini/skills/`
- `~/.devin/skills/`
- `~/.claude/skills/`

## Tool-Specific Skills

Each tool may have its own tool-specific skills. These can be edited directly in the tool's skills directory and will not be overwritten by the sync.

## How to Identify Tool-Specific Skills

If a skill exists in a tool's skills directory but NOT in `~/.agent-config/skills/`, it's a tool-specific skill and can be edited locally. If it exists in both locations, the centralized version wins on sync.

# Task Interruption Handling

When the user sends a new prompt while you are in the middle of an ongoing task, **do not abandon the original task**.

## Core Principle

New prompts during active work are **interruptions or clarifications**, not task replacements. The original task remains active unless explicitly cancelled.

## How to Handle Mid-Task Prompts

1. **Assume continuation**: Treat the new prompt as additional context, a clarification, or a side request related to the ongoing work.
2. **Acknowledge and integrate**: Briefly acknowledge the new input, then continue with the original task, incorporating the new information if relevant.
3. **Explicit cancellation only**: Only abandon the original task if the user explicitly says "stop", "cancel", "never mind", or gives a clear instruction to switch tasks.
4. **Check for dependencies**: If the new prompt seems to be a completely different task, ask for clarification: "Should I pause the current task [X] to work on this new request [Y], or is this related to the ongoing work?"

## Examples

❌ **Wrong:**
```
User: "Fix the login bug"
Agent: [starts working on login bug]
User: "What time is it?"
Agent: "It's 3:45 PM." [abandons login bug work]
```

✅ **Correct:**
```
User: "Fix the login bug"
Agent: [starts working on login bug]
User: "What time is it?"
Agent: "It's 3:45 PM. Continuing with the login bug fix..." [resumes original task]
```

❌ **Wrong:**
```
User: "Deploy the app to production"
Agent: [starts deployment process]
User: "Check if the database is backed up"
Agent: [stops deployment, checks database backup] [deployment abandoned]
```

✅ **Correct:**
```
User: "Deploy the app to production"
Agent: [starts deployment process]
User: "Check if the database is backed up"
Agent: "I'll check the database backup as part of the deployment verification. Continuing with deployment..." [integrates check into ongoing task]
```

## When to Switch Tasks

Only switch tasks when the user:
- Explicitly says "stop", "cancel", "abort", "never mind"
- Says "forget about that, do X instead"
- Clearly indicates the original task is no longer needed
- Uses language that unambiguously cancels the previous work

## Why This Matters

- Users often send quick questions or clarifications while work is in progress
- Abandoning tasks mid-stream wastes progress and context
- Interruptions are usually coordination, not task replacement
- Maintaining task continuity respects the user's original intent

# Usable Git Router (GLOBAL RULE)

Use the `usable-git` MCP server for these exact operations when available:

- `inspect`: local repository state and change fingerprints.
- `review`: staged/unstaged evidence and bounded pagination.
- `history`: bounded local history without fetch.
- `publish`: commit an explicit file list after HEAD/fingerprint checks.
- `push`: update one configured branch using fast-forward or an exact lease.

If MCP is unavailable, use the equivalent JSON CLI:

```text
usable-git <operation> --input -
```

MCP and CLI safety rejections are terminal. Never bypass a rejected `publish` or `push` with broader raw Git commands.

Use exact-path raw Git only when the requested capability is outside the five-operation v1 surface. Preserve unrelated work, avoid broad staging, and keep history linear.

Before `publish`, obtain current HEAD and every selected change fingerprint from `inspect`. Before `push`, supply the configured remote, full source/target branch refs, expected source OID, and explicit push mode.

Never claim a performance improvement without reproducible paired artifacts containing trial counts, environment and component versions, commit SHA, success/final-state oracles, median, p95, confidence intervals, subprocess counts, agent-facing operations, and measured token data.
