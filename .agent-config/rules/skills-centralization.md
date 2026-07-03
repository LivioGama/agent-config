---
trigger: always_on
---
# Skills Centralization

**Skills are centralized** in `.agent-config/skills/` — this is the single source of truth for all shared skills in this repo.

## Golden Rule

**NEVER edit skills directly in tool-specific skills directories** (e.g., `~/.codex/skills/`, `~/.claude/skills/`, `~/.devin/skills/`) — they will be overwritten on the next sync.

## Workflow

1. **Edit** skills in the canonical location: `.agent-config/skills/<skill-name>/SKILL.md`
2. **Sync** to all tools: `cd ~/agent-config && ./sync-skills.sh`
3. **Commit** changes to agent-config repo if needed

## What Gets Synced

The sync script fans out skills from `.agent-config/skills/` to:
- `~/.codex/skills/`
- `~/.cursor/skills/`
- `~/.gemini/skills/`
- `~/.devin/skills/`
- `~/.claude/skills/`

## Tool-Specific Skills

Each tool may have its own tool-specific skills. These can be edited directly in the tool's skills directory and will not be overwritten by the sync.

## How to Identify Tool-Specific Skills

If a skill exists in a tool's skills directory but NOT in `.agent-config/skills/`, it's a tool-specific skill and can be edited locally. If it exists in both locations, the centralized version wins on sync.
