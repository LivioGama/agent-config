#!/usr/bin/env bash
# Pure Rust skills sync script - requires Rust binary
set -euo pipefail
cd "$(dirname "$0")"

RUST_BINARY="target/release/agent-config-sync"
if [ ! -f "$RUST_BINARY" ]; then
    echo "Error: Rust sync binary not found at $RUST_BINARY"
    echo "Run 'cargo build --release' in the agent-config directory first."
    exit 1
fi

exec "$RUST_BINARY" "$@"