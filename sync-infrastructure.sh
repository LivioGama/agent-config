#!/usr/bin/env bash
# Install/sync infrastructure: shell scripts, hooks, MCP configs.
# Called by build.sh after rules+skills fanout.
#
# Idempotent patterns from nvm/rbenv/pyenv:
#   - grep-before-append for shell config sourcing
#   - signature markers for safe re-execution
#   - timestamped backups before any config modification
#   - JSON merge for hooks (preserve existing entries)
set -euo pipefail

CONFIG_ROOT="${AGENT_CONFIG_ROOT:-$HOME/.agent-config}"
BACKUP_DIR="$CONFIG_ROOT/backups"
SIGNATURE="# agent-config infrastructure (auto-managed — do not remove this line)"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

mkdir -p "$BACKUP_DIR"

# ─── Helpers ────────────────────────────────────────────────────────────────

# Backup a file with timestamp before modifying it.
backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    cp "$f" "$BACKUP_DIR/$(basename "$f").backup.$TIMESTAMP" 2>/dev/null || true
  fi
}

# Add a source line to a shell config file if not already present.
# Uses signature markers so re-runs are safe.
add_source_line() {
  local config_file="$1"
  local source_line="$2"

  [ -f "$config_file" ] || touch "$config_file"

  # Already has our signature block → skip
  if grep -qF "$SIGNATURE" "$config_file" 2>/dev/null; then
    return 0
  fi

  backup_file "$config_file"
  {
    printf '\n%s\n' "$SIGNATURE"
    printf '%s\n' "$source_line"
    printf '# end agent-config infrastructure\n'
  } >> "$config_file"
  echo "  Added source line → $config_file"
}

# Remove the agent-config signature block from a shell config.
remove_source_block() {
  local config_file="$1"
  [ -f "$config_file" ] || return 0
  if ! grep -qF "$SIGNATURE" "$config_file" 2>/dev/null; then
    return 0
  fi
  backup_file "$config_file"
  # Delete from signature line to end marker inclusive
  local tmp="${config_file}.tmp.$$"
  sed "/$SIGNATURE/,/^# end agent-config infrastructure$/d" "$config_file" > "$tmp" && mv "$tmp" "$config_file"
  echo "  Removed source block → $config_file"
}

# Merge a hook JSON fragment into a tool's config.json hooks key.
# Preserves existing hooks; only adds/updates from the fragment.
merge_hooks() {
  local target_config="$1"   # e.g. ~/.config/devin/config.json
  local hook_fragment="$2"   # e.g. ~/.agent-config/hooks/devin-exec-zsh.json

  [ -f "$hook_fragment" ] || return 0

  # Create target if missing
  if [ ! -f "$target_config" ]; then
    mkdir -p "$(dirname "$target_config")"
    echo '{}' > "$target_config"
  fi

  backup_file "$target_config"

  # Use python3 for safe JSON merge
  python3 - "$target_config" "$hook_fragment" <<'PY'
import json, os, sys, pathlib
target_path, fragment_path = sys.argv[1], sys.argv[2]
target = json.loads(pathlib.Path(target_path).read_text() or "{}")
fragment = json.loads(pathlib.Path(fragment_path).read_text())

def normalize_cmd(cmd):
    """Expand $HOME for dedup comparison."""
    home = os.path.expanduser("~")
    return cmd.replace("$HOME", home).replace("${HOME}", home)

def entry_commands(entry):
    """Extract all command strings from a hook entry (handles both legacy and nested hooks)."""
    cmds = set()
    if "script" in entry:
        cmds.add(normalize_cmd(entry["script"]))
    if "command" in entry:
        cmds.add(normalize_cmd(entry["command"]))
    for h in entry.get("hooks", []):
        if "command" in h:
            cmds.add(normalize_cmd(h["command"]))
        if "script" in h:
            cmds.add(normalize_cmd(h["script"]))
    return cmds

# Merge hooks key: fragment's hooks are added/updated in target
target_hooks = target.get("hooks", {})
frag_hooks = fragment.get("hooks", {})

for event, entries in frag_hooks.items():
    existing = target_hooks.get(event, [])
    # Build set of existing command signatures for dedup
    existing_sigs = set()
    for e in existing:
        existing_sigs |= entry_commands(e)
    for entry in entries:
        new_sigs = entry_commands(entry)
        if new_sigs & existing_sigs:
            continue  # Already present, skip
        existing.append(entry)
        existing_sigs |= new_sigs
    target_hooks[event] = existing

target["hooks"] = target_hooks
pathlib.Path(target_path).write_text(json.dumps(target, indent=2) + "\n")
print(f"  Merged hooks → {target_path}")
PY
}

# ─── Shell scripts ──────────────────────────────────────────────────────────

install_shell_scripts() {
  local shell_dir="$CONFIG_ROOT/shell"
  if [ ! -d "$shell_dir" ]; then
    return 0
  fi

  echo "Installing shell scripts..."

  # Make all shell scripts executable
  chmod +x "$shell_dir"/*.sh 2>/dev/null || true

  # Add source line to shell configs (idempotent via signature)
  local source_line='for _s in "$HOME/.agent-config/shell"/*.sh; do [ -f "$_s" ] && source "$_s" 2>/dev/null; done; unset _s'

  # zsh: ~/.zshenv (sourced by all zsh invocations including non-interactive)
  add_source_line "$HOME/.zshenv" "$source_line"

  # bash: ~/.bash_profile (login) — Codex uses bash -lc
  add_source_line "$HOME/.bash_profile" "$source_line"

  # bash: ~/.bashrc (non-login interactive) — fallback
  if [ -f "$HOME/.bashrc" ]; then
    add_source_line "$HOME/.bashrc" "$source_line"
  fi

  echo "  Shell scripts installed → $shell_dir ($(ls "$shell_dir"/*.sh 2>/dev/null | wc -l | tr -d ' ') scripts)"
}

# ─── Hook configs ───────────────────────────────────────────────────────────

install_hooks() {
  local hooks_dir="$CONFIG_ROOT/hooks"
  if [ ! -d "$hooks_dir" ]; then
    return 0
  fi

  echo "Installing hook configurations..."

  # Devin: merge hooks/*.json into ~/.config/devin/config.json
  local devin_config="$HOME/.config/devin/config.json"
  for fragment in "$hooks_dir"/*.json; do
    [ -f "$fragment" ] || continue
    merge_hooks "$devin_config" "$fragment"
  done

  # Claude Code: merge into ~/.claude/settings.json
  local claude_config="$HOME/.claude/settings.json"
  for fragment in "$hooks_dir"/*.json; do
    [ -f "$fragment" ] || continue
    # Only merge if fragment has a claude-specific marker in filename
    case "$(basename "$fragment")" in
      claude-*|*.claude.json) merge_hooks "$claude_config" "$fragment" ;;
    esac
  done

  echo "  Hook configs installed → $hooks_dir ($(ls "$hooks_dir"/*.json 2>/dev/null | wc -l | tr -d ' ') configs)"
}

# ─── MCP configs ────────────────────────────────────────────────────────────

install_mcp() {
  local mcp_dir="$CONFIG_ROOT/mcp"
  if [ ! -d "$mcp_dir" ]; then
    return 0
  fi

  echo "Installing MCP configurations..."

  # If sync-mcp-servers command exists, use it for full centralization
  if command -v sync-mcp-servers >/dev/null 2>&1; then
    sync-mcp-servers
    return
  fi

  # Fallback: just report that sync-mcp-servers is not installed
  echo "  (sync-mcp-servers not found — MCP configs stored in $mcp_dir but not deployed)"
  echo "  Install sync-mcp-servers via: ~/.agent-config/install-mcp-sync.sh"
}

# ─── Uninstall ──────────────────────────────────────────────────────────────

uninstall_infrastructure() {
  echo "Uninstalling agent-config infrastructure..."

  # Remove source blocks from shell configs
  remove_source_block "$HOME/.zshenv"
  remove_source_block "$HOME/.bash_profile"
  if [ -f "$HOME/.bashrc" ]; then
    remove_source_block "$HOME/.bashrc"
  fi

  echo "  Removed shell sourcing. Hook/MCP configs left in place (manual removal recommended)."
  echo "  Backups available in: $BACKUP_DIR"
}

# ─── Main ───────────────────────────────────────────────────────────────────

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
