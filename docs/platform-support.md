# Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| macOS | ✅ | Native support, deeplink handler (Swift app) |
| Linux | ✅ | Full rulesync support, deeplink handler (xdg-utils) |
| Windows | ✅ | Full rulesync support, deeplink handler (PowerShell) |

## macOS

- Native Swift app for deeplink handling
- Stable ad-hoc code signing prevents permission re-prompts
- Full rulesync support for 30+ AI tools
- chezmoi integration for multi-machine sync

## Linux

- xdg-utils for URL scheme registration
- .desktop file integration
- Full rulesync support
- chezmoi integration for multi-machine sync

## Windows

- PowerShell-based handler
- Registry-based URL scheme registration
- Full rulesync support
- Batch wrapper for PowerShell script