#!/usr/bin/env bash
# Rust-based skills sync script - replaces original shell implementation
set -euo pipefail
cd "$(dirname "$0")"

# Use Rust binary
if [ -f "target/release/agent-config-sync" ]; then
    exec target/release/agent-config-sync "$@"
elif [ -f "target/debug/agent-config-sync" ]; then
    exec target/debug/agent-config-sync "$@"
else
    echo "Error: Rust sync binary not found. Run 'cargo build --release' first."
    exit 1
fi