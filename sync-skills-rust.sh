#!/usr/bin/env bash
# Rust-based skills sync script - calls the Rust agent-config-sync binary
set -euo pipefail
cd "$(dirname "$0")"

# Use Rust binary if available, otherwise fall back to shell script
if [ -f "target/release/agent-config-sync" ]; then
    exec target/release/agent-config-sync "$@"
else
    # Try debug build if release not available
    if [ -f "target/debug/agent-config-sync" ]; then
        exec target/debug/agent-config-sync "$@"
    else
        echo "Rust sync binary not found. Run 'cargo build --release' first."
        exit 1
    fi
fi