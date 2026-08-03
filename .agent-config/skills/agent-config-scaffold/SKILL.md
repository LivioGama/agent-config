---
name: agent-config-scaffold
description: Scaffold a new agent-config-compatible GitHub repo for a rule, skill, shell script, hook config, or MCP server. Generates README with badges, LICENSE, correct directory structure, and creates the GitHub repo. Use when the user says "create a new skill repo", "scaffold an agent-config project", "make a new rule/skill/MCP repo".
---

# Agent Config Scaffold

Scaffold a new GitHub repo compatible with the `agent-config` deeplink install system. Generates the standard structure, README with install badges, LICENSE, and creates the repo — no copying from existing projects needed.

## When to Use

- "Create a new skill repo for X"
- "Scaffold an agent-config project for Y"
- "Make a new rule/skill/MCP/shell/hook repo"
- "I want to publish Z as an installable agent-config component"

## Component Types

| Type | Directory | Install URL path | Badge label |
|------|-----------|------------------|-------------|
| `skill` | `.agent-config/skills/<name>/SKILL.md` | `.agent-config/skills/<name>/SKILL.md` | Install `<name>` skill |
| `rule` | `rules/<name>.md` | `rules/<name>.md` | Install `<name>` rule |
| `shell` | `shell/<name>.sh` | `shell/<name>.sh` | Install `<name>` shell script |
| `hook` | `hooks/<name>.json` | `hooks/<name>.json` | Install `<name>` hook config |
| `mcp` | `mcp/<name>.json` | `mcp/<name>.json` | Install `<name>` MCP server |
| `infra` | `shell/` + `hooks/` + `.agent-config/skills/` | multiple | Install `<name>` |

## Scaffold Script

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: scaffold-agent-config.sh <type> <name> <description> [github-repo-name]
# type: skill | rule | shell | hook | mcp | infra
# name: kebab-case component name
# description: one-line description
# github-repo-name: optional, defaults to <name>

TYPE="${1:?Usage: scaffold-agent-config.sh <type> <name> <description> [repo-name]}"
NAME="${2:?Component name required (kebab-case)}"
DESC="${3:?Description required}"
REPO_NAME="${4:-$NAME}"
GITHUB_USER="LivioGama"  # change if needed
YEAR="$(date +%Y)"

# Create project directory
PROJECT_DIR="$HOME/$REPO_NAME"
if [ -d "$PROJECT_DIR" ]; then
  echo "Error: $PROJECT_DIR already exists"
  exit 1
fi
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Create directory structure based on type
case "$TYPE" in
  skill)
    mkdir -p ".agent-config/skills/$NAME"
    cat > ".agent-config/skills/$NAME/SKILL.md" <<SKILL
---
name: $NAME
description: $DESC
---

# $(echo "$NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1))substr($i,2)}1')

$DESC

## When to Use

- *(describe trigger conditions)*

## How It Works

*(describe the skill logic)*
SKILL
    INSTALL_PATH=".agent-config/skills/$NAME/SKILL.md"
    BADGE_LABEL="Install $NAME skill"
    TYPE_BADGE="type-skill-black"
    ;;
  rule)
    mkdir -p "rules"
    cat > "rules/$NAME.md" <<RULE
# $(echo "$NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1))substr($i,2)}1')

$DESC

## Rule

*(describe the rule)*
RULE
    INSTALL_PATH="rules/$NAME.md"
    BADGE_LABEL="Install $NAME rule"
    TYPE_BADGE="type-rule-blue"
    ;;
  shell)
    mkdir -p "shell"
    cat > "shell/$NAME.sh" <<SHELL
#!/usr/bin/env bash
set -euo pipefail

# $NAME — $DESC
echo "$NAME: not yet implemented"
SHELL
    chmod +x "shell/$NAME.sh"
    INSTALL_PATH="shell/$NAME.sh"
    BADGE_LABEL="Install $NAME shell script"
    TYPE_BADGE="type-shell-blue"
    ;;
  hook)
    mkdir -p "hooks"
    cat > "hooks/$NAME.json" <<HOOK
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "exec",
        "hooks": [
          {
            "type": "command",
            "command": "\$HOME/.agent-config/shell/$NAME-hook.sh"
          }
        ]
      }
    ]
  }
}
HOOK
    INSTALL_PATH="hooks/$NAME.json"
    BADGE_LABEL="Install $NAME hook config"
    TYPE_BADGE="type-hook-purple"
    ;;
  mcp)
    mkdir -p "mcp"
    cat > "mcp/$NAME.json" <<MCP
{
  "transport": "http",
  "url": "https://example.com/mcp",
  "description": "$DESC"
}
MCP
    INSTALL_PATH="mcp/$NAME.json"
    BADGE_LABEL="Install $NAME MCP server"
    TYPE_BADGE="type-mcp-green"
    ;;
  infra)
    mkdir -p ".agent-config/skills/$NAME" "shell" "hooks"
    cat > ".agent-config/skills/$NAME/SKILL.md" <<SKILL
---
name: $NAME
description: $DESC
---

# $(echo "$NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1))substr($i,2)}1')

$DESC

## When to Use

- *(describe trigger conditions)*

## How It Works

*(describe the infrastructure skill logic)*
SKILL
    cat > "shell/$NAME.sh" <<SHELL
#!/usr/bin/env bash
set -euo pipefail

# $NAME — $DESC
echo "$NAME: not yet implemented"
SHELL
    chmod +x "shell/$NAME.sh"
    INSTALL_PATH=".agent-config/skills/$NAME/SKILL.md"
    BADGE_LABEL="Install $NAME"
    TYPE_BADGE="type-infrastructure-1f883d"
    ;;
  *)
    echo "Unknown type: $TYPE (use: skill|rule|shell|hook|mcp|infra)"
    exit 1
    ;;
esac

# Generate README.md
cat > README.md <<README
# $NAME

![Status](https://img.shields.io/badge/status-active-success)
![Type](https://img.shields.io/badge/$TYPE_BADGE)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

<a href="https://liviogama.github.io/agent-config/redirect.html?url=https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/main/$INSTALL_PATH"><img src="https://raw.githubusercontent.com/$GITHUB_USER/agent-config/main/assets/install-badge-small.jpg" alt="$BADGE_LABEL" height="40" /></a>

$DESC

## Overview

*(describe the project)*

## Installation

### Via agent-config (recommended)

Click the install badge above, or use the install URL:

\`\`\`text
https://liviogama.github.io/agent-config/redirect.html?url=https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/main/$INSTALL_PATH
\`\`\`

### Manual

\`\`\`bash
git clone https://github.com/$GITHUB_USER/$REPO_NAME.git
cd $REPO_NAME
# Copy files to ~/.agent-config/ based on type
\`\`\`

## Usage

*(describe usage)*

## License

MIT

## Contributing

Contributions welcome! This is part of the [agent-config](https://github.com/$GITHUB_USER/agent-config) ecosystem.
README

# Generate LICENSE
cat > LICENSE <<LICENSE
MIT License

Copyright (c) $YEAR $GITHUB_USER

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LICENSE

# Git init + commit
git init
git add .
git commit -m "Initial commit: $NAME ($TYPE)"

# Create GitHub repo and push
gh repo create "$GITHUB_USER/$REPO_NAME" --public --source=. --push --description "$DESC"

echo ""
echo "✅ Created $REPO_NAME ($TYPE)"
echo "   Repo: https://github.com/$GITHUB_USER/$REPO_NAME"
echo "   Install URL:"
echo "   https://liviogama.github.io/agent-config/redirect.html?url=https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/main/$INSTALL_PATH"
```

## Usage Examples

### Scaffold a new skill
```bash
bash scaffold-agent-config.sh skill "my-awesome-skill" "Does awesome things with AI agents"
```

### Scaffold a new rule
```bash
bash scaffold-agent-config.sh rule "no-console-log" "Ban console.log in production code"
```

### Scaffold a new MCP server config
```bash
bash scaffold-agent-config.sh mcp "my-api" "Connect AI agents to my API" "agent-config-mcp-my-api"
```

### Scaffold infrastructure (skill + shell + hooks)
```bash
bash scaffold-agent-config.sh infra "my-infra" "Shell shim + hook for my tool"
```

## What Gets Generated

Every scaffolded repo includes:

| File | Purpose |
|------|---------|
| `README.md` | Badges (status, type, MIT license) + install badge + install URL + overview + usage |
| `LICENSE` | MIT license with current year + GitHub username |
| Component file | Type-specific: `SKILL.md`, `rule.md`, `shell.sh`, `hook.json`, `mcp.json` |
| `.git/` | Initialized with initial commit |

## Install Badge Format

All generated repos use the standard agent-config install badge:

```html
<a href="https://liviogama.github.io/agent-config/redirect.html?url=https://raw.githubusercontent.com/{USER}/{REPO}/main/{PATH}">
  <img src="https://raw.githubusercontent.com/{USER}/agent-config/main/assets/install-badge-small.jpg" alt="Install {NAME}" height="40" />
</a>
```

## Customization

Before running the scaffold script, edit these variables:
- `GITHUB_USER` — your GitHub username (default: `LivioGama`)
- Badge assets — uses `install-badge-small.jpg` from agent-config repo

## After Scaffolding

1. Edit the generated component file (SKILL.md, rule.md, etc.) with real content
2. Edit README.md sections marked with `*(describe...)*`
3. Commit and push:
```bash
git add . && git commit -m "Add content" && git push
```
4. Test the install badge by clicking it
5. Test deeplink install:
```bash
agent-config handle "https://liviogama.github.io/agent-config/redirect.html?url=https://raw.githubusercontent.com/{USER}/{REPO}/main/{PATH}"
```
