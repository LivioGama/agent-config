---
name: mcp-finder
description: Search the official MCP registry for servers to install. Prioritizes OAuth-based servers (no API key management) over token-based servers. Use when the user asks to find, discover, or add MCP servers/capabilities.
---

# MCP Server Finder

Search the [official MCP registry](https://registry.modelcontextprotocol.io) for servers matching a need, **prioritizing OAuth auth** (no API key management) over token/API-key auth.

## When to Use

- User asks to "find an MCP server for X"
- User wants to add a capability (e.g. "I need to search Notion from my agent")
- User asks "what MCP servers are available for Y"
- User wants to extend agent capabilities with external tools

## How It Works

1. **Search** the official registry: `GET https://registry.modelcontextprotocol.io/v0.1/servers?search=<query>&limit=20`
2. **Classify auth** for each result:
   - `api_key` — has `environmentVariables` with `isSecret: true` OR `remotes[].headers` with `isSecret: true`
   - `oauth` — has remote URL with NO secret headers, AND `/.well-known/oauth-protected-resource` responds with valid JSON
   - `none` — local stdio server with no env vars
   - `unknown` — remote with no secret headers but OAuth probe failed
3. **Sort** by auth preference: `oauth` → `none` → `unknown` → `api_key`
4. **Present** top results with install instructions
5. **Install** by adding to `~/.agent-config/mcp/servers.json` and running `sync-mcp-servers`

## Search Command

```bash
# Basic search (returns JSON)
curl -s "https://registry.modelcontextprotocol.io/v0.1/servers?search=<query>&limit=20" | python3 -m json.tool
```

## Auth Classification Script

Run this to search + classify + sort in one step:

```bash
python3 - "$QUERY" <<'PY'
import json, sys, urllib.request, urllib.error

query = sys.argv[1]
url = f"https://registry.modelcontextprotocol.io/v0.1/servers?search={urllib.parse.quote(query)}&limit=20"

try:
    with urllib.request.urlopen(url, timeout=10) as resp:
        data = json.loads(resp.read())
except Exception as e:
    print(f"Error querying registry: {e}")
    sys.exit(1)

def classify_auth(server):
    """Classify auth type: oauth, api_key, none, unknown."""
    has_secret = False
    has_remote = False
    remote_urls = []

    for r in server.get("remotes", []):
        has_remote = True
        if "url" in r:
            remote_urls.append(r["url"])
        for h in r.get("headers", []):
            if h.get("isSecret"):
                has_secret = True

    for p in server.get("packages", []):
        for e in p.get("environmentVariables", []):
            if e.get("isSecret"):
                has_secret = True

    if has_secret:
        return "api_key", remote_urls
    if not has_remote:
        return "none", remote_urls

    # Has remote, no secret headers — probe for OAuth
    for remote_url in remote_urls:
        try:
            # Probe /.well-known/oauth-protected-resource
            base = remote_url.rsplit("/", 1)[0] if "/mcp" in remote_url else remote_url
            well_known = base.rstrip("/") + "/.well-known/oauth-protected-resource"
            req = urllib.request.Request(well_known, headers={"Accept": "application/json", "User-Agent": "MCP-Finder/1.0"})
            with urllib.request.urlopen(req, timeout=5) as resp:
                oauth_data = json.loads(resp.read())
                if "authorization_servers" in oauth_data or "resource" in oauth_data:
                    return "oauth", remote_urls
        except Exception:
            pass

    return "unknown", remote_urls

# Parse and classify
results = []
for entry in data.get("servers", []):
    srv = entry.get("server", {})
    name = srv.get("name", "")
    desc = srv.get("description", "")
    version = srv.get("version", "")
    repo = srv.get("repository", {}).get("url", "")

    auth_type, remote_urls = classify_auth(srv)

    # Get install info
    packages = srv.get("packages", [])
    install_type = "remote" if remote_urls else ("local" if packages else "unknown")
    install_cmd = ""
    if remote_urls:
        install_cmd = f'URL: {remote_urls[0]}'
    elif packages:
        pkg = packages[0]
        registry = pkg.get("registryType", "")
        identifier = pkg.get("identifier", "")
        if registry == "npm":
            install_cmd = f'npx -y {identifier}'
        elif registry == "pypi":
            install_cmd = f'uvx {identifier}'
        else:
            install_cmd = f'{registry}: {identifier}'

    # Collect required env vars
    env_vars = []
    for p in packages:
        for e in p.get("environmentVariables", []):
            env_vars.append(f"{e['name']}={'(secret)' if e.get('isSecret') else '(required)' if e.get('isRequired') else '(optional)'}")

    results.append({
        "name": name,
        "description": desc[:120],
        "auth": auth_type,
        "install_type": install_type,
        "install_cmd": install_cmd,
        "env_vars": env_vars,
        "repo": repo,
        "remote_urls": remote_urls,
    })

# Sort by auth preference: oauth → none → unknown → api_key
auth_order = {"oauth": 0, "none": 1, "unknown": 2, "api_key": 3}
results.sort(key=lambda r: auth_order.get(r["auth"], 4))

# Print results
print(f"\n🔍 Found {len(results)} servers matching '{query}' (sorted by auth preference):\n")
for i, r in enumerate(results, 1):
    auth_icon = {"oauth": "🟢", "none": "⚪", "unknown": "🟡", "api_key": "🔴"}.get(r["auth"], "❓")
    print(f"{i}. {auth_icon} {r['name']} (auth: {r['auth']})")
    print(f"   {r['description']}")
    print(f"   Install: {r['install_cmd']}")
    if r["env_vars"]:
        print(f"   Env vars: {', '.join(r['env_vars'])}")
    if r["repo"]:
        print(f"   Repo: {r['repo']}")
    print()

if not results:
    print("No servers found. Try a broader search term.")
PY
```

## Install Flow

Once the user picks a server, add it to `~/.agent-config/mcp/servers.json`:

### For OAuth/remote servers (preferred):
```bash
python3 - <<'PY'
import json, pathlib

# Edit these:
SERVER_NAME = "<server-name>"
SERVER_URL = "<remote-url>"

config_path = pathlib.Path.home() / ".agent-config" / "mcp" / "servers.json"
config = json.loads(config_path.read_text()) if config_path.exists() else {"servers": {}}
config["servers"][SERVER_NAME] = {
    "transport": "http",
    "url": SERVER_URL
}
config_path.write_text(json.dumps(config, indent=2) + "\n")
print(f"Added {SERVER_NAME} → {config_path}")
PY

# Sync to all CLIs
sync-mcp-servers
```

### For stdio servers (local):
```bash
python3 - <<'PY'
import json, pathlib

# Edit these:
SERVER_NAME = "<server-name>"
COMMAND = "npx"  # or uvx, etc
ARGS = ["-y", "@scope/server-name"]

config_path = pathlib.Path.home() / ".agent-config" / "mcp" / "servers.json"
config = json.loads(config_path.read_text()) if config_path.exists() else {"servers": {}}
config["servers"][SERVER_NAME] = {
    "transport": "stdio",
    "command": COMMAND,
    "args": ARGS
}
config_path.write_text(json.dumps(config, indent=2) + "\n")
print(f"Added {SERVER_NAME} → {config_path}")
PY

# Sync to all CLIs
sync-mcp-servers
```

## Auth Type Legend

| Icon | Auth Type | Meaning | User Action |
|------|-----------|---------|-------------|
| 🟢 | `oauth` | OAuth 2.1 — no API key needed | Just install, agent handles auth flow |
| ⚪ | `none` | No auth required (local stdio) | Just install |
| 🟡 | `unknown` | Remote but auth unclear | May need API key — check docs |
| 🔴 | `api_key` | Requires API key/token | User must get key from provider |

## Examples

### Find a Notion MCP server
```bash
QUERY="notion" python3 - "$QUERY" <<'PY'
# (run the classification script above with QUERY=notion)
PY
```
Expected: `com.notion/mcp` shows as 🟢 oauth (Notion's official MCP server uses OAuth).

### Find a GitHub MCP server
```bash
# Search for github servers
QUERY="github" # run classification script
```

### Find a database MCP server
```bash
QUERY="postgres" # run classification script
```

## Registry API Reference

- **Base URL**: `https://registry.modelcontextprotocol.io/v0.1`
- **Search**: `GET /servers?search=<query>&limit=<n>&cursor=<cursor>`
- **Server details**: `GET /servers/<name>/versions/latest`
- **Docs**: https://registry.modelcontextprotocol.io/docs
- **No auth required** — public read API

## Notes

- The registry is the official one backed by Anthropic, GitHub, Microsoft
- OAuth probing adds ~5s per remote server (timeout) — only probes servers without secret headers
- `sync-mcp-servers` deploys to all 7 CLIs (Claude, Cursor, Codex, Gemini/Antigravity, Windsurf, Devin, Zed) in native format
- Individual MCP configs in each tool are preserved — only canonical servers are synced
