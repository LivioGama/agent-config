#!/usr/bin/env bash
# Handle agent-config:// deeplinks
# Usage: agent-config://https://example.com/rule.md or agent-config://https://example.com/skills/skill-name/SKILL.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Extract URL from the deeplink
DEEPLINK="${1:-}"
SCHEME="agent-config://"

if [[ "$DEEPLINK" != "$SCHEME"* ]]; then
  echo "Error: Invalid deeplink format. Expected ${SCHEME}https://..." >&2
  exit 1
fi

URL="${DEEPLINK#"$SCHEME"}"
if [[ ! "$URL" =~ ^https:// ]]; then
  URL="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$URL")"
fi

# Validate URL
if [[ ! "$URL" =~ ^https:// ]]; then
  echo "Error: Invalid URL format. Expected ${SCHEME}https://..." >&2
  exit 1
fi

# Detect repo directory
if [ -n "${AGENT_CONFIG_REPO_DIR:-}" ]; then
  REPO_DIR="$AGENT_CONFIG_REPO_DIR"
elif [ -x "$SCRIPT_DIR/build.sh" ]; then
  REPO_DIR="$SCRIPT_DIR"
elif [ -d "$HOME/agent-config" ]; then
  REPO_DIR="$HOME/agent-config"
else
  REPO_DIR="$HOME/agent-config"
fi

CONFIG_ROOT="${AGENT_CONFIG_ROOT:-$HOME/.agent-config}"

# Determine if this is a skill or rule based on URL path
URL_WITHOUT_FRAGMENT="${URL%%#*}"
URL_WITHOUT_QUERY="${URL_WITHOUT_FRAGMENT%%\?*}"
URL_PATH=$(printf '%s\n' "$URL_WITHOUT_QUERY" | sed -E 's|^https://[^/]+/||')

if [[ "$URL_PATH" =~ (^|/)skills/([A-Za-z0-9][A-Za-z0-9._-]*)/SKILL\.md$ ]]; then
  # This is a skill
  INSTALL_KIND="skill"
  DEST_DIR="$CONFIG_ROOT/skills"
elif [[ "$URL_PATH" =~ (^|/)\.agent-config/AGENTS\.md$ ]]; then
  INSTALL_KIND="agent config"
  DEST_DIR="$CONFIG_ROOT"
else
  # This is a rule
  INSTALL_KIND="rule"
  DEST_DIR="$CONFIG_ROOT/rules"
fi

# Paths
BUILD_SCRIPT="$REPO_DIR/build.sh"

# Ensure destination directory exists
mkdir -p "$DEST_DIR"

# Determine destination path
if [ "$INSTALL_KIND" = "skill" ]; then
  SKILL_NAME="${BASH_REMATCH[2]}"
  DEST="$DEST_DIR/$SKILL_NAME/SKILL.md"
  mkdir -p "$(dirname "$DEST")"
elif [ "$INSTALL_KIND" = "agent config" ]; then
  DEST="$DEST_DIR/AGENTS.md"
else
  # Extract filename for rules
  FILENAME=$(basename "$URL_PATH")
  if [[ ! "$FILENAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.md$ ]]; then
    echo "Error: Invalid rule filename. Expected a safe .md basename" >&2
    exit 1
  fi
  DEST="$DEST_DIR/$FILENAME"
fi

# Download the file
echo "Downloading $INSTALL_KIND from $URL..."
TMP_DEST="$(dirname "$DEST")/.$(basename "$DEST").download.$$"
trap 'rm -f "$TMP_DEST"' EXIT
curl -fsSL "$URL" -o "$TMP_DEST"

if [ ! -s "$TMP_DEST" ]; then
  echo "Error: Download failed or empty file" >&2
  exit 1
fi

mv -f "$TMP_DEST" "$DEST"
trap - EXIT

echo "Saved to $DEST"

# Run build script
echo "Running build.sh..."
cd "$REPO_DIR"
AGENT_CONFIG_ROOT="$CONFIG_ROOT" ./build.sh

case "$INSTALL_KIND" in
  "agent config") DONE_KIND="Agent Config" ;;
  skill) DONE_KIND="Skill" ;;
  *) DONE_KIND="Rule" ;;
esac
echo "Done! $DONE_KIND installed and synced."
