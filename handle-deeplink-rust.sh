#!/usr/bin/env bash
# Rust-based deeplink handler - calls the Rust agent-config-deeplink binary
set -euo pipefail
cd "$(dirname "$0")"

# Use Rust binary if available, otherwise fall back to shell script
if [ -f "target/release/agent-config-deeplink" ]; then
    exec target/release/agent-config-deeplink "$@"
else
    # Try debug build if release not available
    if [ -f "target/debug/agent-config-deeplink" ]; then
        exec target/debug/agent-config-deeplink "$@"
    else
        echo "Rust deeplink binary not found. Run 'cargo build --release' first."
        exit 1
    fi
fi