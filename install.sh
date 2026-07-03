#!/usr/bin/env bash
# Global install script for agent-config / agent-rules URL scheme handler
set -e

echo "🚀 Installing Agent Config..."

# 1. Clone the repository if not already cloned
if [ ! -d "$HOME/agent-config" ] && [ ! -d "$HOME/agent-rules" ]; then
  echo "Cloning repository to $HOME/agent-config..."
  git clone https://github.com/LivioGama/agent-config.git "$HOME/agent-config"
fi

if [ -d "$HOME/agent-config" ]; then
  REPO_DIR="$HOME/agent-config"
else
  REPO_DIR="$HOME/agent-rules"
fi

cd "$REPO_DIR"

# 2. Build/register the URL scheme handler based on OS
OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  echo "🍎 Building macOS AgentRulesHandler..."
  cd AgentRulesHandler
  ./build.sh
  cd ..
elif [ "$OS" = "Linux" ]; then
  echo "🐧 Installing Linux AgentRulesHandler..."
  cd AgentRulesHandler
  ./install-linux.sh
  cd ..
else
  echo "⚠️ Unsupported OS. Please follow manual installation steps for Windows."
fi

# 3. Run build.sh to deploy configs
echo "🔄 Running initial build..."
./build.sh

echo "✅ Agent Config installed successfully!"