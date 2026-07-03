#!/usr/bin/env bash
# Pure Rust build script - requires Rust binary
set -euo pipefail
cd "$(dirname "$0")"

RUST_BINARY="target/release/agent-config-build"
if [ ! -f "$RUST_BINARY" ]; then
    echo "Error: Rust build binary not found at $RUST_BINARY"
    echo "Run 'cargo build --release' in the agent-config directory first."
    exit 1
fi

exec "$RUST_BINARY" "$@"