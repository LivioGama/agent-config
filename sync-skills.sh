#!/usr/bin/env bash
# Fan out the canonical shared skill set to every tool's skill dir.
# CANONICAL source = .agent-config/skills in repo, ~/.agents/skills when installed.
# Fanout is ADDITIVE (no --delete): each tool keeps its own tool-specific skills
# (e.g. codex-primary-runtime, cursor's gitnexus-*). Deleting a shared skill is a
# job for the cleanup-console, not this sync.
set -euo pipefail

# Use repo path if we're in the agent-config directory, otherwise use home directory
if [ -d ".agent-config/skills" ]; then
  CANON=".agent-config/skills"
elif [ -d "$HOME/.agents/skills" ]; then
  CANON="$HOME/.agents/skills"
else
  echo "no canonical skills dir found"
  exit 0
fi

TOOLS=(codex cursor gemini devin claude)
EXCLUDES=(--exclude='.git' --exclude='.DS_Store' --exclude='*.zip' --exclude='benchmark-playground')

for t in "${TOOLS[@]}"; do
  dest="$HOME/.$t/skills"
  mkdir -p "$dest"
  # -L: resolve symlinks (liza) into real files so each tool dir is self-contained
  #     and survives chezmoi sync to the VPSes.
  rsync -aL "${EXCLUDES[@]}" "$CANON"/ "$dest"/
  echo "synced shared skills → ~/.$t/skills ($(ls "$dest" | wc -l | tr -d ' ') total)"
done
echo "Skills fanout complete (canonical: $CANON)."
