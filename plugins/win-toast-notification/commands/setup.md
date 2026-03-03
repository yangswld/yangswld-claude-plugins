Install BurntToast module, register the `claude-notify://` protocol handler, and register notification identity. Execute all commands below via Bash tool — do not ask the user to copy-paste manually.

## Prerequisites

- Windows 10 / 11
- Windows PowerShell 5.1 (built-in, no extra install needed)

## Step 1: Install BurntToast Module

No Administrator required — `-Scope CurrentUser` installs for current user only. Check if already installed; skip if present:

```powershell
if (Get-Module -ListAvailable -Name BurntToast) {
    Write-Host "BurntToast already installed, skipping."
} else {
    Install-Module -Name BurntToast -Scope CurrentUser -Force
    Write-Host "BurntToast installed successfully."
}
```

If a certificate error occurs during install, retry with `-SkipPublisherCheck`:

```powershell
Install-Module -Name BurntToast -Scope CurrentUser -Force -SkipPublisherCheck
```

### Verify BurntToast

```powershell
Import-Module BurntToast
New-BurntToastNotification -Text 'BurntToast works!'
```

You should see a test notification in the bottom-right corner of your screen.

## Step 2: Register Click-to-Focus Protocol

This registers the `claude-notify://` URI protocol so clicking a notification activates the terminal/IDE window. This is a **one-time setup** and does **not** require Administrator privileges (writes to HKCU only).

Execute directly without prompting the user:

```powershell
# Auto-detect plugin root path (works with any marketplace name)
$pluginRoot = (Get-ChildItem "$env:USERPROFILE\.claude\plugins\cache\*\win-toast-notification" -Directory |
               Select-Object -Last 1).FullName

# If using --plugin-dir for development, override with the actual path:
# $pluginRoot = "C:\path\to\your\project\.claude\marketplace\plugins\win-toast-notification"

$scriptPath = Join-Path $pluginRoot "scripts\focus-terminal.ps1"

# Register protocol in HKCU (no admin needed)
# Reference: https://learn.microsoft.com/en-us/previous-versions/windows/internet-explorer/ie-developer/platform-apis/aa767914(v=vs.85)
$regPath = "HKCU:\Software\Classes\claude-notify"
New-Item -Path "$regPath\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "(Default)" -Value "URL:Claude Notify Protocol"
Set-ItemProperty -Path $regPath -Name "URL Protocol" -Value ""
Set-ItemProperty -Path "$regPath\shell\open\command" -Name "(Default)" `
    -Value "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" `"%1`""

Write-Host "Registered protocol handler at: $scriptPath"
```

### Verify Protocol Registration

```powershell
Get-ItemProperty "HKCU:\Software\Classes\claude-notify"
```

You should see `URL Protocol` and `(Default)` properties listed.

## Step 3: Register Notification Identity

Register a custom application identity (AUMID) so the notification attribution area displays "Claude Code" with a small Claude icon, instead of the default "Windows PowerShell" branding. This is a **one-time setup** and does **not** require Administrator privileges (writes to HKCU only).

Reference: [Microsoft - Register your app in the registry](https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/send-local-toast-other-apps#step-1-register-your-app-in-the-registry)

Execute directly without prompting the user:

```powershell
$pluginRoot = (Get-ChildItem "$env:USERPROFILE\.claude\plugins\cache\*\win-toast-notification" -Directory |
               Select-Object -Last 1).FullName

$iconPath = Join-Path $pluginRoot "images\claude-color-dark-96x96.png"

& (Join-Path $pluginRoot "scripts\register-aumid.ps1") -IconPath $iconPath
```

### Verify AUMID Registration

```powershell
Get-ItemProperty "HKCU:\Software\Classes\AppUserModelId\ClaudeCode.Notification"
```

You should see `DisplayName = Claude Code` and `IconUri` pointing to the icon file.

> **Note**: `IconUri` stores an absolute path. If the plugin is reinstalled to a different cache location, re-run this step to update the icon path.

## Troubleshooting

1. **Network error**: Check your internet connection and access to PowerShell Gallery (https://www.powershellgallery.com)
2. **Module not found after install**: Close and reopen PowerShell, then try `Import-Module BurntToast` again
3. **Click notification does nothing**: Re-run Step 2 to ensure the protocol is registered with the correct plugin path
4. **Protocol path changed**: If you move the plugin to a different location, re-run Step 2 with the updated `$pluginRoot`
5. **Notification shows as "Windows PowerShell"**: Re-run Step 3 to register the notification identity
