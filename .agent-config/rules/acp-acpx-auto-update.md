---
trigger: always_on
---
# ACP/acpx/codex-acp Auto-Update to acp-toolbox Skill

When fixing, debugging, or learning something related to **ACP (Agent Client Protocol)**, **acpx**, or **codex-acp**:

**ALWAYS update the acp-toolbox skill** to document the fix or learning.

This is not optional housekeeping. It is part of finishing the fix. Do it before the final response, after the behavior has been verified.

## Workflow

1. **Fix the issue** in the codebase as normal
2. **Update acp-toolbox skill**:
   - Edit: `.agent-config/skills/acp-toolbox/SKILL.md`
   - Add the fix, gotcha, or learning to the appropriate section
   - If it's Codex-specific, add to `references/shell/09-codex-special-handling.md`
   - If it's a general pattern, add to the relevant section (TypeScript, Shell, General Patterns, or Agent-Specific Quirks)
3. **Commit the skill update**:
   ```bash
   cd ~/agent-config
   git add .agent-config/skills/acp-toolbox
   git commit -m "docs: [what you learned/fix] in acp-toolbox"
   git push
   ```
4. **Sync to all tools**:
   ```bash
   ./sync-skills.sh
   ```

## What Triggers This Rule

Update acp-toolbox when you:
- Fix an ACP stdio framing issue
- Debug a streaming problem (SSE, ndjson, JSON-RPC)
- Resolve a permission round-trip issue
- Fix subprocess lifecycle (orphan reaping, process groups)
- Learn about agent-specific quirks (Codex, Claude, Cursor, Gemini, etc.)
- Discover a gotcha with session management
- Fix timeout or cancellation issues
- Learn about authentication (OAuth vs API keys)
- Debug model selection or capability issues
- Discover the correct ACP package or binary for an agent
- Fix Codex ACP auth, model selection, sandbox, or permission mode behavior

## Codex ACP Defaults Learned the Hard Way

- Use `@zed-industries/codex-acp` for Codex ACP. Do **not** use `@agentclientprotocol/codex-acp`.
- ChatGPT subscription auth is valid via `codex login` / `~/.codex/auth.json`; API-key mode may use `CODEX_API_KEY` or `OPENAI_API_KEY`.
- Do not assume `session/set_model` works. Zed `codex-acp` may expose model/reasoning through `session/new.configOptions`; use prompt-level model/reasoning or `session/set_config_option` where appropriate.
- Trusted direct-write harnesses must call `session/set_mode` with `modeId: "full-access"` before `session/prompt`.
- A write failure mentioning a read-only sandbox is usually a session mode/config problem, not an authentication problem.

## Why This Matters

- acp-toolbox is the **central knowledge base** for all ACP patterns
- Every gotcha cost someone real debugging time
- Documenting it prevents future debugging sessions
- The skill is used across all tools (Codex, Claude Code, Cursor, Gemini, Devin)
- Centralized documentation ensures consistency

## Example

❌ **Wrong:**
```bash
# Fix the bug in code, move on
# The next person hits the same issue and spends 2 hours debugging
```

✅ **Correct:**
```bash
# Fix the bug in code
# Then update acp-toolbox
cd ~/agent-config
vim .agent-config/skills/acp-toolbox/SKILL.md
# Add: "Gotcha: ACP notifications have no 'id' field, use 'method' to detect type"
git add .agent-config/skills/acp-toolbox && git commit -m "docs: add notification id gotcha" && git push
./sync-skills.sh
```

## Reference: acp-toolbox Update Section

See the "Applying Session Learnings" section in acp-toolbox for the full update workflow.
