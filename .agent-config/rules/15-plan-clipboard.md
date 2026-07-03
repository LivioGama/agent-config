---
root: false
targets: ["*"]
description: "Persist generated plans to ~/.plans/ and the clipboard"
globs: ["**/*"]
---

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
