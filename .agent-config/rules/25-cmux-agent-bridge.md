---
name: cmux-agent-bridge
description: Coordinate live coding agents through CMUX transport
---

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
