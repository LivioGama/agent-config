---
root: false
targets: ["*"]
description: "Implement the most recent plan stored in ~/.plans/"
globs: ["**/*"]
---

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
