#!/usr/bin/env bash
# Rust-based deeplink handler - replaces original shell implementation
set -euo pipefail
cd "$(dirname "$0")"

# Use Rust binary
if [ -f "target/release/agent-config-deeplink" ]; then
    exec target/release/agent-config-deeplink "$@"
elif [ -f "target/debug/agent-config-deeplink" ]; then
    exec target/debug/agent-config-deeplink "$@"
else
    echo "Error: Rust deeplink binary not found. Run 'cargo build --release' first."
    exit 1
fi