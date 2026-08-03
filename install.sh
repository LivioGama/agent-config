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

# 1. Initialize the live config root with rules + skills + infrastructure dirs
if [ ! -d "$CONFIG_ROOT/rules" ]; then
  echo "Initializing live config at $CONFIG_ROOT..."
  mkdir -p "$CONFIG_ROOT/rules" "$CONFIG_ROOT/skills" "$CONFIG_ROOT/shell" "$CONFIG_ROOT/hooks" "$CONFIG_ROOT/mcp" "$CONFIG_ROOT/backups"
  if compgen -G "$REPO_DIR/rules/*.md" >/dev/null; then
    rsync -a "$REPO_DIR/rules/" "$CONFIG_ROOT/rules/"
  fi
else
  echo "Live config already exists at $CONFIG_ROOT — preserving."
  mkdir -p "$CONFIG_ROOT/shell" "$CONFIG_ROOT/hooks" "$CONFIG_ROOT/mcp" "$CONFIG_ROOT/backups"
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

# Install infrastructure: shell scripts, hooks, MCP configs
sync-agent-infrastructure install

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

# Install sync-agent-infrastructure (shell scripts, hooks, MCP deploy)
cat > "$LOCAL_BIN/sync-agent-infrastructure" <<'SCRIPT'
#!/usr/bin/env bash
# Install/sync infrastructure: shell scripts, hooks, MCP configs.
# Idempotent: safe to re-run. Uses signature markers + timestamped backups.
set -euo pipefail

CONFIG_ROOT="${AGENT_CONFIG_ROOT:-$HOME/.agent-config}"
BACKUP_DIR="$CONFIG_ROOT/backups"
SIGNATURE="# agent-config infrastructure (auto-managed — do not remove this line)"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

mkdir -p "$BACKUP_DIR"

backup_file() {
  local f="$1"
  [ -f "$f" ] && cp "$f" "$BACKUP_DIR/$(basename "$f").backup.$TIMESTAMP" 2>/dev/null || true
}

add_source_line() {
  local config_file="$1" source_line="$2"
  [ -f "$config_file" ] || touch "$config_file"
  grep -qF "$SIGNATURE" "$config_file" 2>/dev/null && return 0
  backup_file "$config_file"
  { printf '\n%s\n%s\n# end agent-config infrastructure\n' "$SIGNATURE" "$source_line"; } >> "$config_file"
  echo "  Added source line → $config_file"
}

remove_source_block() {
  local config_file="$1"
  [ -f "$config_file" ] || return 0
  grep -qF "$SIGNATURE" "$config_file" 2>/dev/null || return 0
  backup_file "$config_file"
  local tmp="${config_file}.tmp.$$"
  sed "/$SIGNATURE/,/^# end agent-config infrastructure$/d" "$config_file" > "$tmp" && mv "$tmp" "$config_file"
  echo "  Removed source block → $config_file"
}

merge_hooks() {
  local target_config="$1" hook_fragment="$2"
  [ -f "$hook_fragment" ] || return 0
  [ ! -f "$target_config" ] && { mkdir -p "$(dirname "$target_config")"; echo '{}' > "$target_config"; }
  backup_file "$target_config"
  python3 - "$target_config" "$hook_fragment" <<'PY'
import json, os, sys, pathlib
target_path, fragment_path = sys.argv[1], sys.argv[2]
target = json.loads(pathlib.Path(target_path).read_text() or "{}")
fragment = json.loads(pathlib.Path(fragment_path).read_text())

def normalize_cmd(cmd):
    home = os.path.expanduser("~")
    return cmd.replace("$HOME", home).replace("${HOME}", home)

def entry_commands(entry):
    cmds = set()
    if "script" in entry: cmds.add(normalize_cmd(entry["script"]))
    if "command" in entry: cmds.add(normalize_cmd(entry["command"]))
    for h in entry.get("hooks", []):
        if "command" in h: cmds.add(normalize_cmd(h["command"]))
        if "script" in h: cmds.add(normalize_cmd(h["script"]))
    return cmds

target_hooks = target.get("hooks", {})
frag_hooks = fragment.get("hooks", {})
for event, entries in frag_hooks.items():
    existing = target_hooks.get(event, [])
    existing_sigs = set()
    for e in existing: existing_sigs |= entry_commands(e)
    for entry in entries:
        new_sigs = entry_commands(entry)
        if new_sigs & existing_sigs: continue
        existing.append(entry)
        existing_sigs |= new_sigs
    target_hooks[event] = existing
target["hooks"] = target_hooks
pathlib.Path(target_path).write_text(json.dumps(target, indent=2) + "\n")
print(f"  Merged hooks → {target_path}")
PY
}

install_shell_scripts() {
  local shell_dir="$CONFIG_ROOT/shell"
  [ -d "$shell_dir" ] || return 0
  echo "Installing shell scripts..."
  chmod +x "$shell_dir"/*.sh 2>/dev/null || true
  local source_line='for _s in "$HOME/.agent-config/shell"/*.sh; do [ -f "$_s" ] && source "$_s" 2>/dev/null; done; unset _s'
  add_source_line "$HOME/.zshenv" "$source_line"
  add_source_line "$HOME/.bash_profile" "$source_line"
  [ -f "$HOME/.bashrc" ] && add_source_line "$HOME/.bashrc" "$source_line"
  echo "  Shell scripts installed → $shell_dir"
}

install_hooks() {
  local hooks_dir="$CONFIG_ROOT/hooks"
  [ -d "$hooks_dir" ] || return 0
  echo "Installing hook configurations..."
  local devin_config="$HOME/.config/devin/config.json"
  for fragment in "$hooks_dir"/*.json; do
    [ -f "$fragment" ] || continue
    merge_hooks "$devin_config" "$fragment"
  done
  local claude_config="$HOME/.claude/settings.json"
  for fragment in "$hooks_dir"/*.json; do
    [ -f "$fragment" ] || continue
    case "$(basename "$fragment")" in
      claude-*|*.claude.json) merge_hooks "$claude_config" "$fragment" ;;
    esac
  done
  echo "  Hook configs installed → $hooks_dir"
}

install_mcp() {
  local mcp_dir="$CONFIG_ROOT/mcp"
  [ -d "$mcp_dir" ] || return 0
  echo "Installing MCP configurations..."
  if command -v sync-mcp-servers >/dev/null 2>&1; then
    sync-mcp-servers
  else
    echo "  (sync-mcp-servers not found — MCP configs stored in $mcp_dir but not deployed)"
  fi
}

uninstall_infrastructure() {
  echo "Uninstalling agent-config infrastructure..."
  remove_source_block "$HOME/.zshenv"
  remove_source_block "$HOME/.bash_profile"
  [ -f "$HOME/.bashrc" ] && remove_source_block "$HOME/.bashrc"
  echo "  Backups available in: $BACKUP_DIR"
}

case "${1:-install}" in
  install)
    install_shell_scripts
    install_hooks
    install_mcp
    ;;
  uninstall)
    uninstall_infrastructure
    ;;
  *)
    echo "Usage: $0 [install|uninstall]"
    exit 1
    ;;
esac
SCRIPT
chmod +x "$LOCAL_BIN/sync-agent-infrastructure"

# Install sync-mcp-servers (MCP centralization across CLIs)
cp "$REPO_DIR/sync-mcp-servers.sh" "$LOCAL_BIN/sync-mcp-servers"
chmod +x "$LOCAL_BIN/sync-mcp-servers"

echo "Installed build-agent-config, sync-agent-skills, sync-agent-infrastructure, and sync-mcp-servers to $LOCAL_BIN/"

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
echo "   Commands on PATH: build-agent-config, sync-agent-skills, sync-agent-infrastructure, sync-mcp-servers"
echo "   Live config root: ~/.agent-config/"
echo "   Infrastructure:   ~/.agent-config/{shell,hooks,mcp,backups}/"
