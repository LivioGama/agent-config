#!/usr/bin/env bash
# Validate that generated configs match their sources.
# Regenerates AGENTS.md from rules and diffs against deployed copies.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG_ROOT="${AGENT_CONFIG_ROOT:-$HOME/.agent-config}"

echo "Validating configs from $CONFIG_ROOT..."

# Generate AGENTS.md from rules for comparison
export CONFIG_ROOT="$CONFIG_ROOT"
TEMP_AGENTS="$(mktemp)"
trap "rm -f '$TEMP_AGENTS'" EXIT

python3 - "$TEMP_AGENTS" <<'PY'
import glob, os, sys
config_root = os.environ["CONFIG_ROOT"]
output_file = sys.argv[1]
parts = ["# Agent Conventions\n\n_Single source of truth. Edit `~/.agent-config/rules/*.md`, then run `build-agent-config`._\n"]
for f in sorted(glob.glob(os.path.join(config_root, "rules", "*.md"))):
  t = open(f).read()
  if t.startswith("---"): t = t.split("---", 2)[2].lstrip()
  parts.append(t.rstrip())
open(output_file,"w").write("\n\n".join(parts) + "\n")
PY

echo ""
echo "Comparing source AGENTS.md vs generated from rules..."
echo ""

# Compare AGENTS.md source vs generated
echo "=== Source AGENTS.md ==="
if diff -u "$CONFIG_ROOT/AGENTS.md" "$TEMP_AGENTS"; then
  echo "✅ Source AGENTS.md matches generated from rules"
else
  echo "❌ Source AGENTS.md drift detected - edit rules or rebuild"
  exit 1
fi
echo ""

# Compare deployed copies
echo "=== Deployed AGENTS.md copies ==="
DRIFT_FOUND=0

for tool_path in \
  "$HOME/.claude/CLAUDE.md" \
  "$HOME/.claude/AGENTS.md" \
  "$HOME/.codex/AGENTS.md" \
  "$HOME/.devin/AGENTS.md" \
  "$HOME/.cursor/AGENTS.md" \
  "$HOME/.gemini/AGENTS.md"; do
  
  if [ -f "$tool_path" ]; then
    tool_name="$(basename "$(dirname "$tool_path")")/$(basename "$tool_path")"
    if ! diff -q "$CONFIG_ROOT/AGENTS.md" "$tool_path" >/dev/null; then
      echo "❌ $tool_name drift detected"
      DRIFT_FOUND=1
    else
      echo "✅ $tool_name matches"
    fi
  else
    echo "⚠️  $tool_path not found (tool not installed?)"
  fi
done

echo ""
if [ $DRIFT_FOUND -eq 0 ]; then
  echo "✅ All deployed AGENTS.md copies are in sync with source"
  exit 0
else
  echo "❌ Drift detected in one or more deployed copies. Run build-agent-config to sync."
  exit 1
fi