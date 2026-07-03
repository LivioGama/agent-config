---
targets: ["devin"]
description: Force Devin CLI to proactively use parallel subagents without being asked
---
# Parallel Subagents — Use Proactively (HARD RULE)

Default to spawning parallel subagents/sessions for independent work. Do NOT wait for the user to explicitly ask ("use subagents", "parallelize this", "fan out") — that instruction should never be required. If you find yourself about to do 2+ independent things serially, stop and parallelize first.

## When to parallelize (proactively, unannounced)

- **Multi-file/multi-area investigation**: understanding a codebase, tracing a bug across modules, auditing a directory tree — split by file/module/area and run concurrently instead of reading one-by-one.
- **Independent research questions**: any time a task decomposes into 2+ sub-questions whose answers don't depend on each other (compare options, check multiple services/configs, look up multiple docs).
- **Debugging**: never enter a serial try → wait → fail → retry loop. Decompose into independent hypotheses/pieces and investigate them concurrently. Hitting the same issue more than twice in a row without decomposing is a violation.
- **Reviews/audits**: dimension-by-dimension (correctness, security, perf, tests, docs) — each dimension is an independent subagent, not a single serial pass.
- **Any list of N similar independent items** (N files to migrate, N services to check, N endpoints to test) — one subagent per item, not a loop.

## When NOT to parallelize

- A single, small, tightly-coupled task with no independent sub-parts.
- Steps that genuinely depend on each other's output (must stay serial).
- Trivial one-shot lookups where spawning overhead exceeds the work itself.

## Enforcement

- Before starting multi-step work, ask yourself: "does this decompose into independent pieces?" If yes, fan out by default.
- Never ask the user for permission to parallelize — just do it, same as any other execution-strategy decision.
- Report back as if the work were synthesized normally; don't over-narrate the orchestration mechanics unless asked.
