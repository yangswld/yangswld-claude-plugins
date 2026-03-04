# win-toast-notification

Windows Toast notification plugin for Claude Code. Displays a native Windows notification in the bottom-right corner when Claude Code needs your attention. **Click the notification to jump back to your terminal/IDE window.**

## Features

- Native Windows Toast notification via BurntToast
- **Click-to-focus**: clicking a notification activates the terminal/IDE window that spawned it
- Auto-detects host window (Windows Terminal, IntelliJ IDEA, VS Code, etc.)
- Supports multiple concurrent Claude Code sessions in different windows
- Shows "Claude Code needs your attention" as notification text
- Custom AUMID registration: attribution area displays "Claude Code" name and small icon
- Falls back to default PowerShell notification identity when AUMID is not registered

## Requirements

- Windows 10 / 11
- Windows PowerShell 5.1 (built-in)
- Claude Code
- BurntToast PowerShell module (installed automatically by setup)

## Quick Start

### 1. Add the marketplace (first time only)

In Claude Code:

```
/plugin marketplace add yangswld/yangswld-claude-plugins
```

### 2. Install the plugin

```
/plugin install win-toast-notification@yangswld-claude-plugins
```

> Select **"Install for just me (user scope)"** when prompted.

### 3. Run setup (one-time)

Installs BurntToast module, registers the `claude-notify://` click-to-focus protocol, and registers notification identity. Ask Claude to run the setup command — it will execute automatically, no copy-paste needed:

```
/win-toast-notification:setup
```

> No Administrator privileges required (writes to HKCU only).

### 4. Restart Claude Code

Restart your Claude Code session for the hook to take effect.

### 5. Verify

Run any task in Claude Code. When it needs your permission or waits for input, you should see a Toast notification. Click it to jump back to your terminal/IDE window.

## How It Works

### Trigger Conditions

This plugin responds to the `Notification` hook event. Claude Code fires this event in four scenarios (see [Anthropic Hooks Reference](https://docs.anthropic.com/en/docs/claude-code/hooks#notification)):

| `notification_type` | When |
|--------------------|------|
| `permission_prompt` | Claude needs approval to execute a tool (e.g., Bash, Write) |
| `idle_prompt` | Prompt input has been idle for ≥ 60 seconds — Claude is waiting for your response |
| `auth_success` | User authentication has completed successfully |
| `elicitation_dialog` | Claude shows a structured input dialog requesting information from you |

### Notification Flow

1. Claude Code fires the `Notification` hook (see [Trigger Conditions](#trigger-conditions) above)
2. The hook calls `toast-notify.ps1` via PowerShell
3. The script walks the process tree upward to find the host window (terminal/IDE) HWND
4. It creates a Toast notification with a `claude-notify://focus/{HWND}` protocol URI
5. When clicked, Windows invokes `focus-terminal.ps1` via the registered protocol handler
6. The handler parses the HWND from the URI and calls `SetForegroundWindow` to activate the window

### Click-to-Focus Architecture

```
toast-notify.ps1 (Notification Hook)
  1. Walk process tree → find host window HWND
  2. Build notification with Protocol activation
     Launch URI: claude-notify://focus/{HWND}
  3. Submit notification → process exits

     ↓ User clicks notification (no timeout)

OS handles claude-notify://focus/{HWND}
  → Registry lookup → launch focus-terminal.ps1
  → Parse HWND → IsWindow check → SetForegroundWindow
  → Fallback: find WT/IDEA/VS Code process if HWND invalid
```

### Multi-Window Support

Each notification carries the HWND of the window that created it:

| Scenario | Behavior |
|----------|----------|
| Single window | Precise activation |
| Multiple IDE/terminal windows | Each notification activates its own window |
| Window closed after notification | Fallback to finding common host processes |

## Notification Content

### Attribution Area (requires AUMID registration)

- "Claude Code" + small Claude icon (registered via setup Step 3)
- Shows "Windows PowerShell" when AUMID is not registered

### Title

- "Claude Code needs your attention"

## Troubleshooting

### No notification appears

- Verify BurntToast is installed: `Import-Module BurntToast`
- Check Windows notification settings: Settings > Notifications
- Test manually: `New-BurntToastNotification -Text 'Test'`

### Click does nothing

- Verify protocol registration: `Get-ItemProperty "HKCU:\Software\Classes\claude-notify"`
- Re-run the protocol registration step from setup
- If plugin path changed, re-register with the updated path

### Notification shows as "Windows PowerShell"

- Run setup Step 3 to register the notification identity (AUMID)
- Verify registration: `Get-ItemProperty "HKCU:\Software\Classes\AppUserModelId\ClaudeCode.Notification"`

### Module install fails

1. Check network/proxy settings
2. Try: `Install-Module -Name BurntToast -Scope CurrentUser -Force -SkipPublisherCheck`

## Known Limitations

| Limitation | Reason | Impact |
|-----------|--------|--------|
| No tab-level targeting | WT/IDE don't expose Tab API | Must switch tab manually |
| Protocol requires one-time setup | Windows custom URI needs registry entry | Guided in setup, one-time |
| Script path hardcoded in registry | Registry stores absolute path | Re-register if plugin moves |
| AUMID IconUri is an absolute path | Registry stores absolute path | Re-run setup Step 3 after plugin reinstall |
| Single-process multi-window WT | `MainWindowHandle` may return wrong window | Rare scenario, acceptable |

## Development

```bash
# Load plugin in-place during development (changes take effect on restart)
claude --plugin-dir ./plugins/win-toast-notification

# Validate marketplace manifest
claude plugin validate ./.claude-plugin

# Install from marketplace (copies to cache, source changes won't affect installed version)
# Cache location: ~/.claude/plugins/cache/<marketplace>/win-toast-notification/<version>/
/plugin install win-toast-notification@yangswld-claude-plugins
```

## References

- [BurntToast module](https://github.com/Windos/BurntToast)
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks)
- [Claude Code Plugins](https://code.claude.com/docs/en/plugins)
- [Microsoft: Registering a URI Scheme](https://learn.microsoft.com/en-us/previous-versions/windows/internet-explorer/ie-developer/platform-apis/aa767914(v=vs.85))
- [Microsoft: Send toast from unpackaged apps](https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/send-local-toast-other-apps)
- [Win32 SetForegroundWindow](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow)
