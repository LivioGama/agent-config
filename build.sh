#!/usr/bin/env bash
# Regenerate all per-tool configs from the live ~/.agent-config root.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG_ROOT="${AGENT_CONFIG_ROOT:-$HOME/.agent-config}"

if [ ! -d "$CONFIG_ROOT/rules" ]; then
  mkdir -p "$CONFIG_ROOT/rules"
  if compgen -G "rules/*.md" >/dev/null; then
    rsync -a "rules/" "$CONFIG_ROOT/rules/"
  else
    echo "Initialized empty rules directory: $CONFIG_ROOT/rules"
  fi
fi
mkdir -p "$CONFIG_ROOT/skills"

CONFIG_ROOT="$(cd "$CONFIG_ROOT" && pwd)"

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.bun/bin:$PATH"
if ! command -v rulesync >/dev/null 2>&1; then
  echo "Error: rulesync not found in PATH" >&2
  exit 1
fi
RULESYNC_CONFIG="$(mktemp)"
python3 - "$CONFIG_ROOT" "$RULESYNC_CONFIG" <<'PY'
import json
import pathlib
import sys

source_root, output = sys.argv[1], sys.argv[2]
config = json.loads(pathlib.Path("rulesync.jsonc").read_text())
config["sourceRoots"] = [source_root]
pathlib.Path(output).write_text(json.dumps(config, indent=2) + "\n")
PY
rulesync generate --config "$RULESYNC_CONFIG" --targets '*'

# Generate the concatenated AGENTS.md from all rules.
CONFIG_ROOT="$CONFIG_ROOT" python3 - <<'PY'
import glob, os
parts = ["# Agent Conventions\n\n_Single source of truth. Edit `~/.agent-config/rules/*.md`, then run `build-agent-config`._\n"]
for f in sorted(glob.glob(os.path.join(os.environ["CONFIG_ROOT"], "rules", "*.md"))):
    t = open(f).read()
    if t.startswith("---"): t = t.split("---", 2)[2].lstrip()
    parts.append(t.rstrip())
open(os.path.join(os.environ["CONFIG_ROOT"], "AGENTS.md"),"w").write("\n\n".join(parts) + "\n")
PY
echo "Regenerated AGENTS.md + per-tool configs."

# --- Deploy the full ruleset to the live tool locations ---
DEFAULT_CONFIG_ROOT="$(cd "$HOME/.agent-config" 2>/dev/null && pwd || printf '%s' "$HOME/.agent-config")"
if [ "$CONFIG_ROOT" = "$DEFAULT_CONFIG_ROOT" ]; then
mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.devin" "$HOME/.cursor" "$HOME/.gemini"
cp "$CONFIG_ROOT/AGENTS.md" "$HOME/.claude/CLAUDE.md"
cp "$CONFIG_ROOT/AGENTS.md" "$HOME/.claude/AGENTS.md"
cp "$CONFIG_ROOT/AGENTS.md" "$HOME/.codex/AGENTS.md"
cp "$CONFIG_ROOT/AGENTS.md" "$HOME/.devin/AGENTS.md"
cp "$CONFIG_ROOT/AGENTS.md" "$HOME/.cursor/AGENTS.md"
cp "$CONFIG_ROOT/AGENTS.md" "$HOME/.gemini/AGENTS.md"
echo "Deployed ruleset → ~/.claude/CLAUDE.md, ~/.claude/AGENTS.md, ~/.codex/AGENTS.md, ~/.devin/AGENTS.md, ~/.cursor/AGENTS.md, and ~/.gemini/AGENTS.md."

# Devin reads generated modular rule files.
if [ -d "$CONFIG_ROOT/.devin/rules" ] && [ -n "$(ls -A "$CONFIG_ROOT/.devin/rules"/*.md 2>/dev/null || true)" ]; then
  mkdir -p "$HOME/.devin/rules"
  cp "$CONFIG_ROOT/.devin/rules"/*.md "$HOME/.devin/rules/"
  echo "Deployed modular rules → ~/.devin/rules/."
fi

# --- Fan out the canonical skill set ---
[ -x "$(dirname "$0")/sync-skills.sh" ] && "$(dirname "$0")/sync-skills.sh"

# --- Re-vault via chezmoi so the cron propagates to remote hosts ---
if command -v chezmoi >/dev/null 2>&1; then
  for f in "$HOME/.claude/CLAUDE.md" "$HOME/.claude/AGENTS.md" "$HOME/.codex/AGENTS.md" "$HOME/.devin/AGENTS.md" "$HOME/.cursor/AGENTS.md" "$HOME/.gemini/AGENTS.md"; do
    chezmoi managed "$f" >/dev/null 2>&1 && chezmoi re-add "$f" >/dev/null 2>&1 \
      && echo "Re-vaulted $f" || true
  done
fi
else
  echo "Skipped live tool deployment for AGENT_CONFIG_ROOT=$CONFIG_ROOT."
fi
