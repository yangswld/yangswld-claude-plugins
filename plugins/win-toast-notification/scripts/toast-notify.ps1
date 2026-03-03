# Fix 1: Ensure UTF-8 encoding for stdin (Claude Code sends UTF-8 JSON)
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# Fix 2: Ensure WindowsPowerShell user modules path is in PSModulePath
# (fallback for team members who install BurntToast at user level)
$winPSUserModules = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules'
if ($winPSUserModules -notin ($env:PSModulePath -split ';')) {
    $env:PSModulePath = "$winPSUserModules;$env:PSModulePath"
}

Import-Module BurntToast

# Consume stdin to prevent pipe hang (hook always sends JSON via stdin)
[void][Console]::In.ReadToEnd()

# --- Find host window HWND (walk process tree up to first visible window) ---
# Reference: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-iswindowvisible
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinCheck {
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
}
"@

$hostHwnd = 0
$walkPid = $PID
do {
    $wmi = Get-CimInstance Win32_Process -Filter "ProcessId = $walkPid" -ErrorAction SilentlyContinue
    if (-not $wmi) { break }
    $p = Get-Process -Id $wmi.ProcessId -ErrorAction SilentlyContinue
    if ($p -and $p.MainWindowHandle -ne [IntPtr]::Zero -and [WinCheck]::IsWindowVisible($p.MainWindowHandle)) {
        $hostHwnd = $p.MainWindowHandle.ToInt64()
        break
    }
    $walkPid = $wmi.ParentProcessId
} while ($walkPid -ne 0)

# --- Build notification with Protocol activation (click-to-focus) ---
# Reference: https://github.com/Windos/BurntToast (New-BTContent -ActivationType Protocol)
$text1 = New-BTText -Text "Claude Code needs your attention"

$appId = "ClaudeCode.Notification"
$aumidRegistered = Test-Path "HKCU:\Software\Classes\AppUserModelId\$appId"

$binding = New-BTBinding -Children $text1

$visual = New-BTVisual -BindingGeneric $binding
$launchUri = "claude-notify://focus/$hostHwnd"
$content = New-BTContent -Visual $visual -ActivationType Protocol -Launch $launchUri

if ($aumidRegistered) {
    # Bypass BurntToast's Submit-BTNotification (which hardcodes PowerShell's AUMID)
    # Use WinRT API directly with custom AUMID
    # Types from Microsoft.Windows.SDK.NET.dll loaded by BurntToast (BurntToast.psm1:2560)
    $toastXml = [Windows.Data.Xml.Dom.XmlDocument]::new()
    # Strip BurntToast data-binding placeholders {text} → text (same as BurntToast.psm1:2273-2278)
    $xmlContent = $content.GetContent() -replace '<text(.*?)>\{', '<text$1>'
    $xmlContent = $xmlContent.Replace('}</text>', '</text>')
    $toastXml.LoadXml($xmlContent)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($toastXml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
} else {
    Submit-BTNotification -Content $content
}
