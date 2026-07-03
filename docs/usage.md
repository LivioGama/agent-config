# Usage Examples

## Adding a Global Rule

```bash
# Create a new rule in the source
cat > ~/.agent-config/rules/20-my-rule.md << 'EOF'
# My Custom Rule

This is a custom rule for my workflow.

## Requirements

- Always do X
- Never do Y
EOF

# Regenerate configs
./build.sh

# Verify it appears in ~/.agent-config/AGENTS.md
grep "My Custom Rule" ~/.agent-config/AGENTS.md
```

## Adding a Tool-Specific Rule

```bash
# Add a Devin-only rule
cat > .devin/rules/my-devin-rule.md << 'EOF'
# Devin-Specific Rule

This rule only applies to Devin.
EOF

# Regenerate (build.sh copies .devin/rules/*.md to ~/.devin/rules/)
./build.sh
```

## Using in a Project

```bash
# Drop the rules into any project
cp -r ~/.agent-config ./my-project/.agent-config
cp ~/.agent-config/AGENTS.md ./my-project/AGENTS.md

# Your AI tools will now use these rules in that project
```

## Skills Workflow

Skills are centralized in `~/.agent-config/skills/`. After editing:

```bash
# Edit skill
vim ~/.agent-config/skills/my-skill/SKILL.md

# Commit to repo
git add .agent-config/skills/my-skill
git commit -m "docs: update my-skill"
git push

# Sync to all tools
./sync-skills.sh
```
