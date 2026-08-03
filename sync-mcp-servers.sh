#!/usr/bin/env bash
# sync-mcp-servers — centralize MCP server configs across AI agent CLIs.
#
# Canonical source: ~/.agent-config/mcp/servers.json
# Format: { "servers": { "<name>": { "transport": "stdio"|"http", ... } } }
#
# Deploys to each tool's native format:
#   Claude Code:    ~/.claude.json              (JSON, mcpServers)
#   Codex CLI:      ~/.codex/config.toml        (TOML, [mcp_servers.*])
#   Cursor:         ~/.cursor/mcp.json          (JSON, mcpServers)
#   Gemini CLI:     ~/.gemini/settings.json     (JSON, mcpServers, httpUrl)
#   Windsurf:       ~/.codeium/windsurf/mcp_config.json (JSON, serverUrl)
#   Devin CLI:      ~/.config/devin/mcp_config.json     (JSON, mcpServers + transport)
#   Zed:            ~/.config/zed/settings.json (JSON, context_servers)
#
# Auto-migration: if Antigravity CLI is installed (~/.gemini/antigravity-cli/ exists),
# Gemini CLI configs are migrated to Antigravity format with a single log line.
# User does not need to know — seamless.
set -euo pipefail

CONFIG_ROOT="${AGENT_CONFIG_ROOT:-$HOME/.agent-config}"
CANONICAL="$CONFIG_ROOT/mcp/servers.json"
BACKUP_DIR="$CONFIG_ROOT/backups"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

mkdir -p "$BACKUP_DIR"

if [ ! -f "$CANONICAL" ]; then
  echo "No canonical MCP config at $CANONICAL — nothing to sync."
  exit 0
fi

# Snapshot all target MCP configs to /tmp before touching anything.
# Simple, fast, easy to restore from if sync goes wrong.
TMP_BACKUP="/tmp/mcp-backup-$TIMESTAMP"
mkdir -p "$TMP_BACKUP"
for f in \
  "$HOME/.claude.json" \
  "$HOME/.cursor/mcp.json" \
  "$HOME/.codex/config.toml" \
  "$HOME/.codeium/windsurf/mcp_config.json" \
  "$HOME/.config/devin/mcp_config.json" \
  "$HOME/.config/zed/settings.json" \
  "$HOME/.gemini/settings.json" \
  "$HOME/.gemini/antigravity-cli/mcp_config.json" \
  "$HOME/.gemini/antigravity/mcp_config.json"
do
  [ -f "$f" ] && cp "$f" "$TMP_BACKUP/$(basename "$f")"
done
echo "Snapshot → $TMP_BACKUP ($(ls "$TMP_BACKUP" 2>/dev/null | wc -l | tr -d ' ') files)"

# Backup helper
backup_file() {
  [ -f "$1" ] && cp "$1" "$BACKUP_DIR/$(basename "$1").backup.$TIMESTAMP" 2>/dev/null || true
}

# Detect Antigravity CLI installation (Google retired Gemini CLI 2026-06-18)
ANTIGRAVITY_CLI_DIR="$HOME/.gemini/antigravity-cli"
ANTIGRAVITY_DESKTOP_DIR="$HOME/.gemini/antigravity"
has_antigravity() {
  [ -d "$ANTIGRAVITY_CLI_DIR" ] || [ -d "$ANTIGRAVITY_DESKTOP_DIR" ]
}

# Main sync via Python (handles all format conversions + migration)
python3 - "$CANONICAL" "$BACKUP_DIR" "$TIMESTAMP" <<'PY'
import json, os, pathlib, sys, re

canonical_path, backup_dir, timestamp = sys.argv[1], sys.argv[2], sys.argv[3]
home = pathlib.Path.home()

canonical = json.loads(pathlib.Path(canonical_path).read_text())
servers = canonical.get("servers", {})

if not servers:
    print("No servers in canonical config — nothing to sync.")
    sys.exit(0)

def backup(path):
    p = pathlib.Path(path)
    if p.exists():
        backup_p = pathlib.Path(backup_dir) / f"{p.name}.backup.{timestamp}"
        backup_p.write_bytes(p.read_bytes())

def load_json(path, default=None):
    p = pathlib.Path(path)
    if not p.exists():
        return default if default is not None else {}
    try:
        return json.loads(p.read_text() or "{}")
    except json.JSONDecodeError:
        return default if default is not None else {}

# ─── Secret sanitization ─────────────────────────────────────────────────────
# Refuse to write any header value that looks like a credential.
# Forces env-var indirection (bearer_token_env_var for Codex, env in stdio)
# instead of leaking raw secrets to 6+ config files on disk.

_SECRET_VALUE_PATTERNS = [
    re.compile(r'^Bearer\s+\S', re.IGNORECASE),       # "Bearer sk-..."
    re.compile(r'^Basic\s+\S', re.IGNORECASE),        # "Basic dXNlcjpwYXNz"
    re.compile(r'^sk-[A-Za-z0-9]{16,}'),              # OpenAI-style keys
    re.compile(r'^[A-Fa-f0-9]{32,}$'),                # bare hex keys (>=32)
    re.compile(r'^[A-Za-z0-9_-]{40,}$'),              # base64url-ish tokens (>=40)
]

_SECRET_KEY_PATTERNS = [
    re.compile(r'auth', re.IGNORECASE),
    re.compile(r'token', re.IGNORECASE),
    re.compile(r'secret', re.IGNORECASE),
    re.compile(r'password', re.IGNORECASE),
    re.compile(r'api.?key', re.IGNORECASE),
]

def is_secret_header(key, value):
    """True if a header looks like a credential — by value pattern OR key name."""
    if not isinstance(value, str):
        return False
    if any(p.search(value) for p in _SECRET_VALUE_PATTERNS):
        return True
    if any(p.search(key) for p in _SECRET_KEY_PATTERNS):
        return True
    return False

def sanitize_headers(headers, server_name, target_name):
    """Return headers with secret values stripped. Warn for each removal."""
    safe = {}
    for k, v in headers.items():
        if is_secret_header(k, v):
            print(f"  🚫 {target_name}: refusing to write secret in header '{k}' "
                  f"for server '{server_name}' — use bearer_token_env_var (Codex) "
                  f"or env-var indirection instead. Header dropped.")
        else:
            safe[k] = v
    return safe

def write_json(path, data):
    p = pathlib.Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    backup(path)
    p.write_text(json.dumps(data, indent=2) + "\n")

def write_text(path, text):
    p = pathlib.Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    backup(path)
    p.write_text(text)

# ─── Format converters ──────────────────────────────────────────────────────

def to_claude_cursor_format(servers):
    """Claude Code, Cursor: { mcpServers: { name: { command, args, env } | { url } } }"""
    out = {}
    for name, srv in servers.items():
        if srv.get("transport") == "http" or "url" in srv:
            entry = {"url": srv["url"]}
            if "headers" in srv:
                safe = sanitize_headers(srv["headers"], name, "Claude/Cursor")
                if safe:
                    entry["headers"] = safe
            if "type" in srv:
                entry["type"] = srv["type"]
        else:
            entry = {}
            if "command" in srv:
                entry["command"] = srv["command"]
            if "args" in srv:
                entry["args"] = srv["args"]
            if "env" in srv:
                entry["env"] = srv["env"]
        out[name] = entry
    return {"mcpServers": out}

def to_gemini_format(servers):
    """Gemini CLI: { mcpServers: { name: { command, args } | { httpUrl, headers } } }"""
    out = {}
    for name, srv in servers.items():
        if srv.get("transport") == "http" or "url" in srv:
            entry = {"httpUrl": srv["url"]}
            if "headers" in srv:
                safe = sanitize_headers(srv["headers"], name, "Gemini")
                if safe:
                    entry["headers"] = safe
            if "timeout" in srv:
                entry["timeout"] = srv["timeout"]
        else:
            entry = {}
            if "command" in srv:
                entry["command"] = srv["command"]
            if "args" in srv:
                entry["args"] = srv["args"]
            if "timeout" in srv:
                entry["timeout"] = srv["timeout"]
        out[name] = entry
    return {"mcpServers": out}

def to_antigravity_format(servers):
    """Antigravity: { mcpServers: { name: { command, args } | { serverUrl } } }"""
    out = {}
    for name, srv in servers.items():
        if srv.get("transport") == "http" or "url" in srv:
            entry = {"serverUrl": srv["url"]}
            if "headers" in srv:
                safe = sanitize_headers(srv["headers"], name, "Antigravity")
                if safe:
                    entry["headers"] = safe
        else:
            entry = {}
            if "command" in srv:
                entry["command"] = srv["command"]
            if "args" in srv:
                entry["args"] = srv["args"]
            if "env" in srv:
                entry["env"] = srv["env"]
        out[name] = entry
    return {"mcpServers": out}

def to_windsurf_format(servers):
    """Windsurf: { mcpServers: { name: { command, args, env } | { serverUrl } } }"""
    out = {}
    for name, srv in servers.items():
        if srv.get("transport") == "http" or "url" in srv:
            entry = {"serverUrl": srv["url"]}
            if "headers" in srv:
                safe = sanitize_headers(srv["headers"], name, "Windsurf")
                if safe:
                    entry["headers"] = safe
        else:
            entry = {}
            if "command" in srv:
                entry["command"] = srv["command"]
            if "args" in srv:
                entry["args"] = srv["args"]
            if "env" in srv:
                entry["env"] = srv["env"]
        out[name] = entry
    return {"mcpServers": out}

def to_devin_format(servers):
    """Devin CLI: { mcpServers: { name: { command, args, transport: 'stdio' } | { url, transport: 'http', headers } } }"""
    out = {}
    for name, srv in servers.items():
        transport = srv.get("transport", "http" if "url" in srv else "stdio")
        if transport == "http" or "url" in srv:
            entry = {"url": srv["url"], "transport": "http"}
            if "headers" in srv:
                safe = sanitize_headers(srv["headers"], name, "Devin")
                if safe:
                    entry["headers"] = safe
        else:
            entry = {"transport": "stdio"}
            if "command" in srv:
                entry["command"] = srv["command"]
            if "args" in srv:
                entry["args"] = srv["args"]
        out[name] = entry
    return {"mcpServers": out}

def to_zed_format(servers):
    """Zed: { context_servers: { name: { enabled: true, settings: {...} } } }"""
    out = {}
    for name, srv in servers.items():
        if srv.get("transport") == "http" or "url" in srv:
            # Zed doesn't natively support HTTP MCP in context_servers; skip with warning
            print(f"  ⚠️  Zed: skipping HTTP server '{name}' (not supported in context_servers)")
            continue
        settings = {}
        if "command" in srv:
            # Zed uses extension-based servers typically; map command to settings
            settings["command"] = srv["command"]
        if "args" in srv:
            settings["args"] = srv["args"]
        # Map env vars to settings (Zed convention)
        for k, v in srv.get("env", {}).items():
            settings[k.lower()] = v
        out[name] = {"enabled": True, "settings": settings}
    return {"context_servers": out}

def to_codex_toml(servers):
    """Codex CLI: TOML [mcp_servers.name] sections"""
    lines = []
    for name, srv in servers.items():
        lines.append(f"[mcp_servers.{name}]")
        if srv.get("transport") == "http" or "url" in srv:
            lines.append(f'url = "{srv["url"]}"')
            if "bearer_token_env_var" in srv:
                lines.append(f'bearer_token_env_var = "{srv["bearer_token_env_var"]}"')
            if "headers" in srv:
                safe = sanitize_headers(srv["headers"], name, "Codex")
                for k, v in safe.items():
                    lines.append(f'headers.{k} = "{v}"')
        else:
            if "command" in srv:
                lines.append(f'command = "{srv["command"]}"')
            if "args" in srv:
                args_str = ", ".join(f'"{a}"' for a in srv["args"])
                lines.append(f'args = [{args_str}]')
            if "env" in srv:
                for k, v in srv["env"].items():
                    lines.append(f'env.{k} = "{v}"')
            if "startup_timeout_sec" in srv:
                lines.append(f'startup_timeout_sec = {srv["startup_timeout_sec"]}')
            if "enabled" in srv:
                lines.append(f'enabled = {"true" if srv["enabled"] else "false"}')
        lines.append("")
    return "\n".join(lines)

def merge_json_config(path, new_servers_section, section_key):
    """Additive merge: only touch servers present in canonical. Preserve everything else."""
    existing = load_json(path, {})
    existing_servers = existing.get(section_key, {})
    canonical_names = set(new_servers_section[section_key].keys())
    touched = 0
    added = 0
    for name, entry in new_servers_section[section_key].items():
        if name in existing_servers:
            touched += 1
        else:
            added += 1
        existing_servers[name] = entry  # canonical wins for managed servers
    existing[section_key] = existing_servers
    # Count servers we left untouched
    untouched = len([n for n in existing_servers if n not in canonical_names])
    write_json(path, existing)
    print(f"  → {path}: {added} added, {touched} updated, {untouched} individual preserved")

def merge_toml_config(path, canonical_servers_toml, canonical_names):
    """Additive TOML merge: only replace [mcp_servers.<name>] sections for servers
    in canonical. All other mcp_servers sections (individually configured) are preserved."""
    p = pathlib.Path(path)
    existing_text = p.read_text() if p.exists() else ""
    backup(path)

    lines = existing_text.split("\n")
    output_lines = []
    skip = False
    skipped_names = []
    touched = 0

    for line in lines:
        # Detect start of a canonical mcp_servers section → skip it (will re-add from canonical)
        m = re.match(r'^\[mcp_servers\.(\w+)\]', line)
        if m and m.group(1) in canonical_names:
            skip = True
            touched += 1
            continue
        # Detect start of a non-canonical mcp_servers section → preserve it
        if m and m.group(1) not in canonical_names:
            skip = False
            output_lines.append(line)
            continue
        # Detect any other section header → stop skipping
        if skip and line.startswith("[") and not line.startswith("[mcp_servers"):
            skip = False
        if not skip:
            output_lines.append(line)
        elif skip and line.strip() == "":
            # Skip blank lines within removed sections
            continue

    # Remove trailing empty lines
    while output_lines and output_lines[-1].strip() == "":
        output_lines.pop()

    # Append canonical mcp_servers sections
    if canonical_servers_toml.strip():
        output_lines.append("")
        output_lines.append(canonical_servers_toml.rstrip())

    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("\n".join(output_lines) + "\n")

    # Count preserved individual servers
    preserved = 0
    for m in re.finditer(r'^\[mcp_servers\.(\w+)\]', existing_text, re.MULTILINE):
        if m.group(1) not in canonical_names:
            preserved += 1

    added = len(canonical_names) - touched
    print(f"  → {path}: {max(added,0)} added, {touched} updated, {preserved} individual preserved")

# ─── Deploy to each tool ────────────────────────────────────────────────────

print("Syncing MCP servers to AI agent CLIs...")

# Claude Code: ~/.claude.json
claude_path = home / ".claude.json"
claude_fmt = to_claude_cursor_format(servers)
merge_json_config(str(claude_path), claude_fmt, "mcpServers")

# Cursor: ~/.cursor/mcp.json
cursor_path = home / ".cursor" / "mcp.json"
cursor_fmt = to_claude_cursor_format(servers)  # same format as Claude
merge_json_config(str(cursor_path), cursor_fmt, "mcpServers")

# Codex CLI: ~/.codex/config.toml
codex_path = home / ".codex" / "config.toml"
codex_toml = to_codex_toml(servers)
merge_toml_config(str(codex_path), codex_toml, set(servers.keys()))

# Windsurf: ~/.codeium/windsurf/mcp_config.json
windsurf_path = home / ".codeium" / "windsurf" / "mcp_config.json"
windsurf_fmt = to_windsurf_format(servers)
merge_json_config(str(windsurf_path), windsurf_fmt, "mcpServers")

# Devin CLI: ~/.config/devin/mcp_config.json
devin_path = home / ".config" / "devin" / "mcp_config.json"
devin_fmt = to_devin_format(servers)
merge_json_config(str(devin_path), devin_fmt, "mcpServers")

# Zed: ~/.config/zed/settings.json
zed_path = home / ".config" / "zed" / "settings.json"
if zed_path.exists() or (home / ".config" / "zed").exists():
    zed_fmt = to_zed_format(servers)
    if zed_fmt["context_servers"]:
        merge_json_config(str(zed_path), zed_fmt, "context_servers")

# ─── Gemini CLI → Antigravity auto-migration ────────────────────────────────
# Google retired Gemini CLI on 2026-06-18. If Antigravity is installed,
# migrate seamlessly with a single log line. User doesn't need to know.

antigravity_cli_dir = home / ".gemini" / "antigravity-cli"
antigravity_desktop_dir = home / ".gemini" / "antigravity"
gemini_settings = home / ".gemini" / "settings.json"

if antigravity_cli_dir.exists() or antigravity_desktop_dir.exists():
    # Antigravity is installed — write to Antigravity format, not Gemini
    antigravity_path = antigravity_cli_dir / "mcp_config.json"
    if not antigravity_cli_dir.exists():
        antigravity_path = antigravity_desktop_dir / "mcp_config.json"
    antigravity_fmt = to_antigravity_format(servers)
    merge_json_config(str(antigravity_path), antigravity_fmt, "mcpServers")

    # If Gemini CLI config still exists and has MCP servers, migrate them
    if gemini_settings.exists():
        gemini_config = load_json(str(gemini_settings), {})
        gemini_mcp = gemini_config.get("mcpServers", {})
        if gemini_mcp:
            # Merge Gemini's existing servers into Antigravity config
            existing_antigravity = load_json(str(antigravity_path), {})
            existing_servers = existing_antigravity.get("mcpServers", {})
            for name, srv in gemini_mcp.items():
                if name not in existing_servers:
                    # Convert httpUrl → serverUrl
                    if "httpUrl" in srv:
                        srv = {**srv, "serverUrl": srv.pop("httpUrl")}
                    existing_servers[name] = srv
            existing_antigravity["mcpServers"] = existing_servers
            write_json(str(antigravity_path), existing_antigravity)
            print(f"  📦 Migrated {len(gemini_mcp)} servers from Gemini CLI → Antigravity")

            # Remove mcpServers from Gemini config (deprecated)
            backup(str(gemini_settings))
            gemini_config.pop("mcpServers", None)
            pathlib.Path(gemini_settings).write_text(json.dumps(gemini_config, indent=2) + "\n")
            print(f"  📝 Gemini CLI MCP config cleared (deprecated — use Antigravity)")
else:
    # No Antigravity — write to Gemini CLI format (legacy)
    gemini_fmt = to_gemini_format(servers)
    merge_json_config(str(gemini_settings), gemini_fmt, "mcpServers")

print(f"\n✅ MCP sync complete. {len(servers)} servers deployed.")
PY
