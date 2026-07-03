#!/usr/bin/env bash
# Regenerate all per-tool configs + the combined AGENTS.md from .rulesync/rules/
set -e
cd "$(dirname "$0")"

# Sync public rules to local ignored rules folder before building
if [ -d "rules" ] && [ -n "$(ls -A rules/*.md 2>/dev/null)" ]; then
  mkdir -p ".agent-config/rules"
  cp rules/*.md .agent-config/rules/
fi

export PATH="$HOME/.bun/bin:$PATH"
rulesync generate --targets '*'
python3 - <<'PY'
import glob, os
parts = ["# Agent Conventions\n\n_Single source of truth. Edit `.agent-config/rules/*.md`, then run `./build.sh`._\n"]
for f in sorted(glob.glob(".agent-config/rules/*.md")):
    t = open(f).read()
    if t.startswith("---"): t = t.split("---", 2)[2].lstrip()
    parts.append(t.rstrip())
open("AGENTS.md","w").write("\n\n".join(parts) + "\n")
PY
echo "Regenerated AGENTS.md + per-tool configs."

# --- Deploy the full ruleset to the live agent-config locations ---
# Claude reads ~/.claude/CLAUDE.md (single file) — give it the FULL concatenation,
# not just the root rule, so every rule is active. AGENTS.md mirror is for Codex/Devin.
cp AGENTS.md "$HOME/.claude/CLAUDE.md"
cp AGENTS.md "$HOME/.claude/AGENTS.md"
echo "Deployed ruleset → ~/.claude/CLAUDE.md and ~/.claude/AGENTS.md."

# Codex keeps Codex-specific global policy in AGENTS.md, so do not overwrite the
# whole file with the Claude-oriented combined ruleset. Instead, inject the
# shared browser policy from the canonical tooling rule.
python3 - <<'PY'
from pathlib import Path

home = Path.home()
root = Path.cwd()
tooling = (root / ".agent-config/rules/20-tooling.md").read_text()


def find_heading(text: str, heading_prefix: str, start: int = 0) -> int:
    offset = 0
    for line in text.splitlines(keepends=True):
        if offset >= start and line.startswith(heading_prefix):
            return offset
        offset += len(line)
    raise ValueError(f"heading not found: {heading_prefix}")


def extract_section(text: str, heading_prefix: str, next_heading_prefix: str | None = None) -> str:
    start = find_heading(text, heading_prefix)
    end = find_heading(text, next_heading_prefix, start + 1) if next_heading_prefix else len(text)
    return text[start:end].strip()


browser_policy = "\n\n".join(
    [
        extract_section(tooling, "## Browser automation", "## suparun"),
        extract_section(tooling, "## Browser testing"),
    ]
)
managed_block = (
    "<!-- shared-browser-policy:start -->\n"
    + browser_policy
    + "\n<!-- shared-browser-policy:end -->"
)

old_browser_lines = (
    "- *** Browser verification preference:",
    "- *** Browser verification must be headed Brave by default:",
    "- *** Headless browser verification must use Obscura by default:",
    "- *** Browser verification defaults to headless Lightpanda:",
    "- *** Headed Brave is opt-in by situation:",
)

for rel in (".Codex/AGENTS.md", ".codex/AGENTS.md"):
    path = home / rel
    if not path.exists():
        continue

    text = path.read_text()
    if "<!-- shared-browser-policy:start -->" in text:
        before, rest = text.split("<!-- shared-browser-policy:start -->", 1)
        _, after = rest.split("<!-- shared-browser-policy:end -->", 1)
        text = before.rstrip() + "\n\n" + managed_block + after
    else:
        lines = [
            line
            for line in text.splitlines()
            if not line.startswith(old_browser_lines)
        ]
        text = "\n".join(lines).rstrip() + "\n"
        anchor = "\n---\n\n## Codex Auth"
        if anchor in text:
            text = text.replace(anchor, "\n\n" + managed_block + "\n" + anchor, 1)
        else:
            text = text.rstrip() + "\n\n" + managed_block + "\n"

    path.write_text(text.rstrip() + "\n")

print("Deployed shared browser policy → ~/.Codex/AGENTS.md and ~/.codex/AGENTS.md.")
PY

# Devin reads generated modular rule files. Keep the live rule directory in sync
# without deleting any Devin-local files that may exist there.
if [ -d ".devin/rules" ] && [ -n "$(ls -A .devin/rules/*.md 2>/dev/null)" ]; then
  mkdir -p "$HOME/.devin/rules"
  cp .devin/rules/*.md "$HOME/.devin/rules/"
  echo "Deployed modular rules → ~/.devin/rules/."
fi

# --- Fan out the canonical skill set (.agent-config/skills) to every tool ---
[ -x "$(dirname "$0")/sync-skills.sh" ] && "$(dirname "$0")/sync-skills.sh"

# --- Re-vault via chezmoi so the 30-min cron propagates to genesis + exodus ---
if command -v chezmoi >/dev/null 2>&1; then
  for f in "$HOME/.claude/CLAUDE.md" "$HOME/.claude/AGENTS.md" "$HOME/.Codex/AGENTS.md" "$HOME/.codex/AGENTS.md"; do
    chezmoi managed "$f" >/dev/null 2>&1 && chezmoi re-add "$f" >/dev/null 2>&1 \
      && echo "Re-vaulted $f" || true
  done
fi
