# Claude Code Plugins

A collection of plugins for [Claude Code](https://code.claude.com/) by yang.jianrong.

## Installation

Add this marketplace to Claude Code:

```
/plugin marketplace add yangswld/yangswld-claude-plugins
```

## Available Plugins

### win-toast-notification

Windows Toast notification when Claude Code needs your attention. Click the notification to jump back to your terminal/IDE window.

**Features:**
- Native Windows Toast notification via BurntToast
- Click-to-focus: clicking a notification activates the terminal/IDE window
- Auto-detects host window (Windows Terminal, IntelliJ IDEA, VS Code, etc.)
- Shows session name (set via `/rename`) as notification title
- Shows model name in notification body
- Cross-platform safe: silently skips on macOS/Linux

**Installation:**
```
/plugin install win-toast-notification@yangswld-claude-plugins
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.
