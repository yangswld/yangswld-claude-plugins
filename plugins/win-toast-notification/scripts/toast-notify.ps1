# Fix 1: Ensure UTF-8 encoding for stdin (Claude Code sends UTF-8 JSON)
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# Fix 2: Ensure WindowsPowerShell user modules path is in PSModulePath
# (fallback for team members who install BurntToast at user level)
$winPSUserModules = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules'
if ($winPSUserModules -notin ($env:PSModulePath -split ';')) {
    $env:PSModulePath = "$winPSUserModules;$env:PSModulePath"
}

Import-Module BurntToast

# Read JSON data from stdin
$inputJson = [Console]::In.ReadToEnd()
$data = $inputJson | ConvertFrom-Json

# Get session title from transcript file
$sessionTitle = "Claude Code"
$transcriptPath = $data.transcript_path

if ($transcriptPath -and (Test-Path $transcriptPath)) {
    # Search for custom-title record (get LAST/most recent)
    $customTitleLine = Select-String -Path $transcriptPath -Pattern '"type":"custom-title"' -SimpleMatch | Select-Object -Last 1
    if ($customTitleLine) {
        $customTitleData = $customTitleLine.Line | ConvertFrom-Json
        if ($customTitleData.customTitle) {
            $sessionTitle = $customTitleData.customTitle
        }
    }
}

# Fallback to session_id if customTitle not found
if ($sessionTitle -eq "Claude Code" -and $data.session_id) {
    $sessionTitle = $data.session_id
}

# Get model name from transcript file (get LAST/most recent assistant message)
$modelName = "Claude Code"
if ($transcriptPath -and (Test-Path $transcriptPath)) {
    $assistantLine = Select-String -Path $transcriptPath -Pattern '"type":"assistant"' -SimpleMatch | Select-Object -Last 1
    if ($assistantLine) {
        $assistantData = $assistantLine.Line | ConvertFrom-Json
        if ($assistantData.message.model) {
            $modelName = $assistantData.message.model
        }
    }
}

# Resolve icon path relative to script location (portable, no hardcoded user path)
$iconPath = Join-Path $PSScriptRoot "..\images\claude-color-dark-96x96.png"

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
$text1 = New-BTText -Text $sessionTitle
$text2 = New-BTText -Text "$modelName needs your attention"
$appLogoImage = New-BTImage -Source $iconPath -AppLogoOverride -Crop Circle
$binding = New-BTBinding -Children $text1, $text2 -AppLogoOverride $appLogoImage
$visual = New-BTVisual -BindingGeneric $binding

$launchUri = "claude-notify://focus/$hostHwnd"
$content = New-BTContent -Visual $visual -ActivationType Protocol -Launch $launchUri

Submit-BTNotification -Content $content
