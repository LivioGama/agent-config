---
trigger: always_on
---
# Editing Global Rules and Skills

When the user asks to "add to AGENTS.md and CLAUDE.md global" or "add a skill" or similar phrasing:

**NEVER edit the generated files in the tool directories** (`~/.claude/CLAUDE.md`, `~/.claude/AGENTS.md`, `~/.codex/AGENTS.md`, `~/.codex/skills/`, `~/.claude/skills/`, etc.).

Instead, edit the source and let it pass through to the tools.

## Rules Workflow

1. **Add the rule to the source**: Create or edit a file in `.agent-config/rules/`
2. **Regenerate configs**: Run `./build.sh` (this syncs the rule to all tool directories)
3. **Verify deployment**: Check that the rule appears in the generated files
4. **Commit and push**: `git add .agent-config/rules/ rules/ AGENTS.md && git commit -m "..." && git push`

## Skills Workflow

1. **Add the skill to the source**: Create or edit in `.agent-config/skills/<skill-name>/SKILL.md`
2. **Sync to all tools**: Run `./sync-skills.sh` (fans out to `~/.codex/skills`, `~/.cursor/skills`, `~/.gemini/skills`, `~/.devin/skills`, `~/.claude/skills`)
3. **Commit changes to agent-config repo if needed**

## Why This Matters

- The tool directories (`~/.claude/`, `~/.codex/`, etc.) contain **generated files**
- Editing them directly will be **overwritten** the next time `./build.sh` or `./sync-skills.sh` runs
- The source of truth for rules is `.agent-config/rules/*.md` in this agent-config repo
- The source of truth for skills is `.agent-config/skills/` in this agent-config repo
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
vim .agent-config/rules/my-new-rule.md
# Regenerate and sync to all tools
./build.sh
# Commit
git add .agent-config/rules/ rules/ AGENTS.md && git commit -m "add: my new rule" && git push
```

❌ **Wrong (Skills):**
```bash
# Editing the skill in the tool directory
vim ~/.codex/skills/my-skill/SKILL.md
```

✅ **Correct (Skills):**
```bash
# Edit the source skill
vim .agent-config/skills/my-skill/SKILL.md
# Sync to all tools
./sync-skills.sh
```

## Tool-Specific Rules

If the rule is specific to a single tool, add it to that tool's rules directory:
- Codex: `.codex/rules/` or `.codex/memories/`
- Claude Code: `.claude/rules/`
- Devin: `.devin/rules/`

Then run `./build.sh` to deploy.
