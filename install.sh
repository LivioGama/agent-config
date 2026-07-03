#!/usr/bin/env bash
# Global install script for the agent-config:// URL scheme handler
set -e

echo "🚀 Installing Agent Config..."

# 1. Clone the repository if not already cloned
if [ ! -d "$HOME/agent-config" ]; then
  echo "Cloning repository to $HOME/agent-config..."
  git clone https://github.com/LivioGama/agent-config.git "$HOME/agent-config"
fi

REPO_DIR="$HOME/agent-config"
CONFIG_ROOT="$HOME/.agent-config"

cd "$REPO_DIR"

if [ ! -d "$CONFIG_ROOT/rules" ]; then
  echo "Initializing live config at $CONFIG_ROOT..."
  mkdir -p "$CONFIG_ROOT/rules" "$CONFIG_ROOT/skills"
  if compgen -G "$REPO_DIR/rules/*.md" >/dev/null; then
    rsync -a "$REPO_DIR/rules/" "$CONFIG_ROOT/rules/"
  fi
fi

# 2. Build/register the URL scheme handler based on OS
OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  echo "🍎 Building macOS AgentConfigHandler..."
  cd AgentConfigHandler
  ./build.sh
  cd ..
elif [ "$OS" = "Linux" ]; then
  echo "🐧 Installing Linux AgentConfigHandler..."
  cd AgentConfigHandler
  ./install-linux.sh
  cd ..
else
  echo "⚠️ Unsupported OS. Please follow manual installation steps for Windows."
fi

# 3. Run build.sh to deploy configs
echo "🔄 Running initial build..."
AGENT_CONFIG_ROOT="$CONFIG_ROOT" ./build.sh

echo "✅ Agent Config installed successfully!"
