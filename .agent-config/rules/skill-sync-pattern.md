---
trigger: always_on
---
# Skill Update and Sync Pattern

When you create, edit, or fix a skill, you MUST sync it to all AI tools before declaring work complete.

## Workflow

1. **Create or edit the skill** in `.agent-config/skills/your-skill/SKILL.md`
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

- Skills are centralized in `.agent-config/skills/` but each tool needs its own copy
- The sync script fans out skills to Codex, Claude Code, Devin, Cursor, etc.
- Without syncing, your skill changes won't be available to other agents
- This ensures consistency across all AI coding tools

## Quick Reference

**Sync script location:** `~/agent-config/sync-skills.sh`  
**Canonical skills source:** `.agent-config/skills/` (within agent-config repo)  
**Tool destinations:** `~/.codex/skills`, `~/.cursor/skills`, `~/.devin/skills`, `~/.claude/skills`, `~/.gemini/skills`

## One-Click Installation

You can install this rule directly via deeplink to enforce skill syncing:

[![Install Skill Sync Rule](https://img.shields.io/badge/Install_Skill_Sync_Rule-blue?style=for-the-badge)](agent-config://https://raw.githubusercontent.com/LivioGama/agent-config/main/.agent-config/rules/skill-sync-pattern.md)
