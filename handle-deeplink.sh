#!/usr/bin/env bash
# Handle agent-rules:// deeplinks
# Usage: agent-rules://https://example.com/rule.md or agent-rules://https://example.com/skills/skill-name/SKILL.md

set -e

# Extract URL from the deeplink
DEEPLINK="$1"
URL="${DEEPLINK#agent-rules://}"

# Validate URL
if [[ ! "$URL" =~ ^https?:// ]]; then
  echo "Error: Invalid URL format. Expected agent-rules://https://..." >&2
  exit 1
fi

# Detect repo directory
if [ -d "$HOME/agent-config" ]; then
  REPO_DIR="$HOME/agent-config"
else
  REPO_DIR="$HOME/agent-rules"
fi

# Determine if this is a skill or rule based on URL path
if [[ "$URL" =~ /skills/[^/]+/SKILL\.md$ ]]; then
  # This is a skill
  IS_SKILL=true
  DEST_DIR="$REPO_DIR/.agent-config/skills"
else
  # This is a rule
  IS_SKILL=false
  DEST_DIR="$REPO_DIR/.agent-config/rules"
fi

# Paths
BUILD_SCRIPT="$REPO_DIR/build.sh"

# Ensure destination directory exists
mkdir -p "$DEST_DIR"

# Extract path structure from URL
URL_PATH=$(echo "$URL" | sed -E 's|https?://[^/]+/||')

# Determine destination path
if [ "$IS_SKILL" = true ]; then
  # Extract skill name from path like "skills/my-skill/SKILL.md"
  SKILL_NAME=$(echo "$URL_PATH" | sed -E 's|skills/([^/]+)/SKILL\.md|\1|')
  DEST="$DEST_DIR/$SKILL_NAME/SKILL.md"
  mkdir -p "$(dirname "$DEST")"
else
  # Extract filename for rules
  FILENAME=$(basename "$URL")
  DEST="$DEST_DIR/$FILENAME"
fi

# Download the file
echo "Downloading $([ "$IS_SKILL" = true ] && echo "skill" || echo "rule") from $URL..."
curl -fsSL "$URL" -o "$DEST"

if [ ! -s "$DEST" ]; then
  echo "Error: Download failed or empty file" >&2
  rm -f "$DEST"
  exit 1
fi

echo "Saved to $DEST"

# Run build script
echo "Running build.sh..."
cd "$REPO_DIR"
./build.sh

echo "Done! $([ "$IS_SKILL" = true ] && echo "Skill" || echo "Rule") installed and synced."
