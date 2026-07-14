# Never Include Personal Config in Repository

**HARD RULE**: Never commit personal configuration data from `.agent-config/` to this repository.

## What This Means

The `.agent-config/` directory in this repository is a **template/example** structure, not your actual personal config. Your real personal config lives at `~/.agent-config/` (in your home directory).

## What to Commit

**DO commit:**
- `build.sh` - the sync script
- `sync-skills.sh` - the skills sync script
- `README.md` - documentation
- `rules/` - public rules for distribution (optional, sparse)
- `docs/` - documentation
- `AgentConfigHandler/` - deeplink handler
- `.gitignore` - gitignore configuration
- Other repository infrastructure files

**NEVER commit:**
- `.agent-config/rules/` - your personal rules
- `.agent-config/skills/` - your personal skills
- `.agent-config/AGENTS.md` - your generated concatenated rules
- Any other personal configuration data

## Why This Matters

- This repository is a **public distribution tool**, not a personal config backup
- Personal config contains private rules, skills, and settings specific to you
- Committing personal data pollutes the repository with unrelated content
- The `.gitignore` already excludes `.agent-config/rules/` and `.agent-config/skills/`

## Workflow

1. **Edit your personal config** in `~/.agent-config/` (your home directory)
2. **Run `./build.sh`** to sync to all tools
3. **Optionally copy useful rules** to `rules/` for public distribution
4. **Commit only the public repository files**, never your personal config

## Verification

Before committing, check:
```bash
git status
```

If you see any `.agent-config/` files staged, unstage them:
```bash
git restore --staged .agent-config/
```

Only commit files that are part of the repository infrastructure, not your personal configuration.
