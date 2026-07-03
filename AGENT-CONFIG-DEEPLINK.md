# Agent Config Deeplink Handler

## Overview

Cross-platform handler that processes `agent-config://` deeplinks to download and install agent rules or skills automatically. Supports macOS, Linux, and Windows.

## Installation

### macOS
```bash
cd AgentConfigHandler
./build.sh
```

This builds the app to `$HOME/Applications/AgentConfigHandler.app` and registers the URL scheme.

### Linux
```bash
cd AgentConfigHandler
./install-linux.sh
```

This creates a `.desktop` file and registers the URL scheme via xdg-utils.

### Windows
```powershell
cd AgentConfigHandler
.\install-windows.ps1
```

This registers the URL scheme in the Windows registry and creates the handler script.

## Usage

Click a link with format:

**For rules:**
```
agent-config://https://example.com/rule.md
```

**For skills:**
```
agent-config://https://example.com/skills/skill-name/SKILL.md
```

The handler will:
1. Detect if URL is a rule or skill based on path pattern
2. Download the file from the URL
3. Save it to `.agent-config/rules/` or `.agent-config/skills/` accordingly
4. Run `build.sh` to sync the changes

## Testing

### macOS
```bash
# Test with a real URL
open 'agent-config://https://raw.githubusercontent.com/user/repo/main/rule.md'

# Or run the app directly
$HOME/Applications/AgentConfigHandler.app/Contents/MacOS/AgentConfigHandler 'agent-config://https://example.com/rule.md'
```

### Linux
```bash
# Test with a real URL
xdg-open 'agent-config://https://raw.githubusercontent.com/user/repo/main/rule.md'

# Or run the handler directly
./handle-deeplink.sh 'agent-config://https://example.com/rule.md'
```

### Windows
```powershell
# Test with a real URL
start agent-config://https://raw.githubusercontent.com/user/repo/main/rule.md

# Or run the handler directly
.\handle-deeplink.ps1 'agent-config://https://example.com/rule.md'
```

## Platform Details

### macOS
- **Bundle ID**: `com.agentrules.handler`
- **Executable**: `AgentConfigHandler` (Swift)
- **Signature**: Stable ad-hoc (prevents permission re-prompts)
- **Location**: `$HOME/Applications/AgentConfigHandler.app`

### Linux
- **Handler**: `handle-deeplink.sh` (Bash)
- **Desktop file**: `$HOME/.local/share/applications/agent-config-handler.desktop`
- **Registration**: xdg-utils

### Windows
- **Handler**: `handle-deeplink.ps1` (PowerShell)
- **Registration**: Windows Registry (HKCU:\Software\Classes\agent-config)
- **Batch wrapper**: `handle-deeplink.bat`

## Files

### macOS
- `Info.plist` - App metadata and URL scheme registration
- `main.swift` - Swift handler that downloads and builds
- `build.sh` - Build script that creates the .app bundle

### Linux
- `install-linux.sh` - Installation script for Linux
- `handle-deeplink.sh` - Bash handler (shared)

### Windows
- `install-windows.ps1` - Installation script for Windows
- `handle-deeplink.ps1` - PowerShell handler
- `handle-deeplink.bat` - Batch wrapper for PowerShell script
