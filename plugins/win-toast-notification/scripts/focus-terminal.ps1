# focus-terminal.ps1 — Invoked by claude-notify:// protocol handler
# Parses HWND from URI and activates the corresponding window
#
# Usage: OS calls this script with the full URI as argument
#   e.g. powershell.exe -File focus-terminal.ps1 "claude-notify://focus/3150104"
#
# References:
#   - SetForegroundWindow: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow
#   - ShowWindow: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showwindow
#   - IsWindow: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-iswindow

param([string]$Uri)

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinApi {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
}
"@

$SW_RESTORE = 9
$hwnd = [IntPtr]::Zero

# Method 1: Parse HWND from URI
if ($Uri -match 'claude-notify://focus/(\d+)') {
    $parsed = [IntPtr]::new([long]$Matches[1])
    if ([WinApi]::IsWindow($parsed)) {
        $hwnd = $parsed
    }
}

# Method 2: Fallback — find common host processes with visible windows
if ($hwnd -eq [IntPtr]::Zero) {
    $hostNames = @('WindowsTerminal', 'idea64', 'Code', 'pwsh', 'powershell')
    foreach ($name in $hostNames) {
        $proc = Get-Process -Name $name -ErrorAction SilentlyContinue |
                Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
                Select-Object -First 1
        if ($proc) { $hwnd = $proc.MainWindowHandle; break }
    }
}

# Activate window
if ($hwnd -ne [IntPtr]::Zero) {
    if ([WinApi]::IsIconic($hwnd)) { [WinApi]::ShowWindow($hwnd, $SW_RESTORE) }
    [WinApi]::SetForegroundWindow($hwnd)
}
