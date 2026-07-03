#!/usr/bin/env bash
# Rust-based build script - calls the Rust agent-config-build binary
set -euo pipefail
cd "$(dirname "$0")"

# Use Rust binary if available, otherwise fall back to shell script
if [ -f "target/release/agent-config-build" ]; then
    exec target/release/agent-config-build "$@"
else
    # Try debug build if release not available
    if [ -f "target/debug/agent-config-build" ]; then
        exec target/debug/agent-config-build "$@"
    else
        echo "Rust build binary not found. Run 'cargo build --release' first."
        exit 1
    fi
fi