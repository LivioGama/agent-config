#!/usr/bin/env bash
# Rust-based build script - replaces original shell implementation
set -euo pipefail
cd "$(dirname "$0")"

# Use Rust binary
if [ -f "target/release/agent-config-build" ]; then
    exec target/release/agent-config-build "$@"
elif [ -f "target/debug/agent-config-build" ]; then
    exec target/debug/agent-config-build "$@"
else
    echo "Error: Rust build binary not found. Run 'cargo build --release' first."
    exit 1
fi