# Design Philosophy

## Single Source of Truth

Edit `~/.agent-config/rules/*.md`, never the generated files. The build script regenerates all per-tool configs from the source.

## Additive Fanout

Skills deployment preserves tool-specific skills. Each tool keeps its own unique skills while sharing the centralized set.

## Stable Identities

macOS apps use stable ad-hoc signing to prevent permission re-prompts. Consistent bundle IDs and signatures across updates.

## No Merge Commits

Enforce linear git history via built-in rule. Use rebase, fast-forward, or cherry-pick for branch integration.

## Verification First

BUILD → VERIFY → NEXT workflow enforced in rules. Developers run their code; unverified claims are forbidden.

## Centralization

All shared skills live in `~/.agent-config/skills/`. Tool-specific skills can exist in tool directories but are edited in place.

## Cross-Platform

Support macOS, Linux, and Windows with platform-appropriate handlers. Consistent behavior across all platforms.
