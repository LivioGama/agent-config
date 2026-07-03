# Deeplink Badges

Add badges to your README for one-click rule/skill installation via `agent-rules://` deeplinks.

**Requires:** Deeplink handler installed (see [deeplink.md](deeplink.md))

## Usage

**Global rules:**
```markdown
[![Install Agent Config](https://raw.githubusercontent.com/LivioGama/agent-config/main/assets/install-badge-small.jpg)](agent-rules://https://raw.githubusercontent.com/LivioGama/agent-config/main/AGENTS.md)
```

**Single rule:**
```markdown
[![Install Rule](https://img.shields.io/badge/Install_Rule-green?style=for-the-badge)](agent-rules://https://raw.githubusercontent.com/user/repo/main/.agent-config/rules/rule.md)
```

**Skill:**
```markdown
[![Install Skill](https://img.shields.io/badge/Install_Skill-purple?style=for-the-badge)](agent-rules://https://raw.githubusercontent.com/user/repo/main/.agent-config/skills/skill/SKILL.md)
```

**Custom badge image:**
```markdown
[![Install](https://raw.githubusercontent.com/LivioGama/agent-config/main/assets/install-badge-small.jpg)](agent-rules://https://raw.githubusercontent.com/user/repo/main/.agent-config/rules/rule.md)
```

## Examples

[![Install Agent Config](../assets/install-badge-small.jpg)](agent-rules://https://raw.githubusercontent.com/LivioGama/agent-config/main/AGENTS.md) — All global rules

[![Install Telegraphic Brevity](../assets/install-badge-small.jpg)](agent-rules://https://raw.githubusercontent.com/LivioGama/agent-config/main/.agent-config/rules/05-telegraphic-brevity.md) — Telegraphic Brevity rule

[![Install Project Context](../assets/install-badge-small.jpg)](agent-rules://https://raw.githubusercontent.com/LivioGama/agent-config/main/.agent-config/skills/project-context/SKILL.md) — Project Context skill