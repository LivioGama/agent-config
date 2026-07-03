#!/usr/bin/env bash
# Rust-based install script - replaces original shell implementation
set -euo pipefail
cd "$(dirname "$0")"

# Use Rust binary
if [ -f "target/release/agent-config-install" ]; then
    exec target/release/agent-config-install "$@"
elif [ -f "target/debug/agent-config-install" ]; then
    exec target/debug/agent-config-install "$@"
else
    echo "Error: Rust install binary not found. Run 'cargo build --release' first."
    exit 1
fi