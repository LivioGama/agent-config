#!/usr/bin/env bash
# Rust-based install script - calls the Rust agent-config-install binary
set -euo pipefail
cd "$(dirname "$0")"

# Use Rust binary if available, otherwise fall back to shell script
if [ -f "target/release/agent-config-install" ]; then
    exec target/release/agent-config-install "$@"
else
    # Try debug build if release not available
    if [ -f "target/debug/agent-config-install" ]; then
        exec target/debug/agent-config-install "$@"
    else
        echo "Rust install binary not found. Run 'cargo build --release' first."
        exit 1
    fi
fi