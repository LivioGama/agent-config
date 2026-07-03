#!/usr/bin/env bash
# Install agent-config:// URL scheme handler for Linux

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
HANDLER_SCRIPT="$REPO_DIR/handle-deeplink.sh"
DESKTOP_FILE="$HOME/.local/share/applications/agent-config-handler.desktop"

# Ensure handler script is executable
chmod +x "$HANDLER_SCRIPT"

# Create .desktop file
mkdir -p "$HOME/.local/share/applications"

cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Agent Config Handler
Exec=$HANDLER_SCRIPT %u
Type=Application
Terminal=true
MimeType=x-scheme-handler/agent-config;
NoDisplay=true
EOF

# Update desktop database
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
xdg-mime default "$(basename "$DESKTOP_FILE")" x-scheme-handler/agent-config 2>/dev/null || true

echo "Installed agent-config:// handler for Linux"
echo "Test with: xdg-open 'agent-config://https://example.com/rule.md'"
