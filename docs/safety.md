# Safety Features

## ANTHROPIC_API_KEY Ban

- **Never use API keys** — OAuth authentication only
- Prevents 401 crashes from key conflicts
- Enforced across all tools and subprocesses

## Stable macOS Signing

- Ad-hoc identity prevents permission re-prompts
- Consistent bundle ID: `com.agentrules.handler`
- No repeated macOS security prompts

## Infrastructure Guards

- **Dokploy patterns** — Standard deployment configurations
- **Traefik network fixes** — Resolved common networking issues
- **Remote Chrome by default** — No local Chrome for testing

## Browser Automation

- Remote Chrome instance for consistent testing
- Agent-browser integration for programmatic control
- No local browser dependencies

## Multi-Machine Sync

- chezmoi vaulting propagates rules to all machines
- Consistent environment across development machines
- Automated 30-minute cron sync