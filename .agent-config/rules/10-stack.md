---
root: false
targets: ["*"]
description: "Tech stack: bun, TypeScript, Next.js, Tailwind v4, React Query"
globs: ["**/*.ts", "**/*.tsx", "**/*.css", "**/package.json"]
---

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
