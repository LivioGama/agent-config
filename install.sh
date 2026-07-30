#!/usr/bin/env bash
# Global install script for the agent-config:// URL scheme handler.
#
# Installs the build/sync scripts to ~/.local/bin/ so the machine does NOT
# need to keep this repo around after installation. The live config root is
# ~/.agent-config/ (dot folder) — that is the only directory agents reference.
set -e

echo "🚀 Installing Agent Config..."

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_ROOT="$HOME/.agent-config"
LOCAL_BIN="$HOME/.local/bin"

# 1. Initialize the live config root with rules + skills
if [ ! -d "$CONFIG_ROOT/rules" ]; then
  echo "Initializing live config at $CONFIG_ROOT..."
  mkdir -p "$CONFIG_ROOT/rules" "$CONFIG_ROOT/skills"
  if compgen -G "$REPO_DIR/rules/*.md" >/dev/null; then
    rsync -a "$REPO_DIR/rules/" "$CONFIG_ROOT/rules/"
  fi
else
  echo "Live config already exists at $CONFIG_ROOT — preserving."
fi

# Copy rulesync config + .rulesync so build-agent-config is self-contained
cp "$REPO_DIR/rulesync.jsonc" "$CONFIG_ROOT/rulesync.jsonc" 2>/dev/null || true
if [ -d "$REPO_DIR/.rulesync" ]; then
  rsync -a "$REPO_DIR/.rulesync/" "$CONFIG_ROOT/.rulesync/"
fi

# 2. Install standalone scripts to ~/.local/bin/
mkdir -p "$LOCAL_BIN"

cat > "$LOCAL_BIN/build-agent-config" <<'SCRIPT'
#!/usr/bin/env bash
# Regenerate all per-tool configs from the live ~/.agent-config root.
set -euo pipefail

CONFIG_ROOT="$HOME/.agent-config"
cd "$CONFIG_ROOT"

if [ ! -d "$CONFIG_ROOT/rules" ]; then
  mkdir -p "$CONFIG_ROOT/rules"
  echo "Initialized empty rules directory: $CONFIG_ROOT/rules"
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

mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.devin" "$HOME/.cursor" "$HOME/.gemini"
cp "$CONFIG_ROOT/AGENTS.md" "$HOME/.claude/CLAUDE.md"
cp "$CONFIG_ROOT/AGENTS.md" "$HOME/.claude/AGENTS.md"
cp "$CONFIG_ROOT/AGENTS.md" "$HOME/.codex/AGENTS.md"
cp "$CONFIG_ROOT/AGENTS.md" "$HOME/.devin/AGENTS.md"
cp "$CONFIG_ROOT/AGENTS.md" "$HOME/.cursor/AGENTS.md"
cp "$CONFIG_ROOT/AGENTS.md" "$HOME/.gemini/AGENTS.md"
echo "Deployed ruleset → ~/.claude/CLAUDE.md, ~/.claude/AGENTS.md, ~/.codex/AGENTS.md, ~/.devin/AGENTS.md, ~/.cursor/AGENTS.md, and ~/.gemini/AGENTS.md."

if [ -d "$CONFIG_ROOT/.devin/rules" ] && [ -n "$(ls -A "$CONFIG_ROOT/.devin/rules"/*.md 2>/dev/null || true)" ]; then
  mkdir -p "$HOME/.devin/rules"
  cp "$CONFIG_ROOT/.devin/rules"/*.md "$HOME/.devin/rules/"
  echo "Deployed modular rules → ~/.devin/rules/."
fi

sync-agent-skills

if command -v chezmoi >/dev/null 2>&1; then
  for f in "$HOME/.claude/CLAUDE.md" "$HOME/.claude/AGENTS.md" "$HOME/.codex/AGENTS.md" "$HOME/.devin/AGENTS.md" "$HOME/.cursor/AGENTS.md" "$HOME/.gemini/AGENTS.md"; do
    chezmoi managed "$f" >/dev/null 2>&1 && chezmoi re-add "$f" >/dev/null 2>&1 \
      && echo "Re-vaulted $f" || true
  done
fi
SCRIPT
chmod +x "$LOCAL_BIN/build-agent-config"

cat > "$LOCAL_BIN/sync-agent-skills" <<'SCRIPT'
#!/usr/bin/env bash
# Fan out the canonical shared skill set to every tool's skill dir.
set -euo pipefail

if [ -d "$HOME/.agent-config/skills" ]; then
  CANON="$HOME/.agent-config/skills"
else
  echo "no canonical skills dir found"
  exit 0
fi

TOOLS=(codex cursor gemini devin claude)
EXCLUDES=(--exclude='.git' --exclude='.DS_Store' --exclude='*.zip' --exclude='benchmark-playground')

for t in "${TOOLS[@]}"; do
  dest="$HOME/.$t/skills"
  mkdir -p "$dest"
  rsync -aL "${EXCLUDES[@]}" "$CANON"/ "$dest"/
  echo "synced shared skills → ~/.$t/skills ($(ls "$dest" | wc -l | tr -d ' ') total)"
done
echo "Skills fanout complete (canonical: $CANON)."
SCRIPT
chmod +x "$LOCAL_BIN/sync-agent-skills"

echo "Installed build-agent-config and sync-agent-skills to $LOCAL_BIN/"

# 3. Build/register the URL scheme handler based on OS
OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  echo "🍎 Building macOS AgentConfigHandler..."
  cd "$REPO_DIR/AgentConfigHandler"
  ./build.sh
elif [ "$OS" = "Linux" ]; then
  echo "🐧 Installing Linux AgentConfigHandler..."
  cd "$REPO_DIR/AgentConfigHandler"
  ./install-linux.sh
else
  echo "⚠️ Unsupported OS. Please follow manual installation steps for Windows."
fi

# 4. Run initial build
echo "🔄 Running initial build..."
build-agent-config

echo "✅ Agent Config installed successfully!"
echo "   Commands on PATH: build-agent-config, sync-agent-skills"
echo "   Live config root: ~/.agent-config/"
