# Register a custom AUMID (Application User Model ID) for Claude Code notifications.
# This makes Windows display "Claude Code" with a small Claude icon in the notification
# attribution area, instead of the default "Windows PowerShell" branding.
#
# One-time setup, no admin required (writes to HKCU only). Idempotent — safe to re-run.
#
# Reference: https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/send-local-toast-other-apps#step-1-register-your-app-in-the-registry

param(
    [string]$AppId = "ClaudeCode.Notification",
    [string]$DisplayName = "Claude Code",
    [string]$IconPath
)

$regPath = "HKCU:\Software\Classes\AppUserModelId\$AppId"

if (-not (Test-Path $regPath)) {
    New-Item -Path "HKCU:\Software\Classes\AppUserModelId" -Name $AppId -Force | Out-Null
}

New-ItemProperty -Path $regPath -Name DisplayName -Value $DisplayName -PropertyType String -Force | Out-Null

if ($IconPath -and (Test-Path $IconPath -PathType Leaf)) {
    $absPath = (Resolve-Path $IconPath).Path
    New-ItemProperty -Path $regPath -Name IconUri -Value $absPath -PropertyType ExpandString -Force | Out-Null
}

# ShowInSettings = 1: allow users to manage notification preferences in Windows Settings
New-ItemProperty -Path $regPath -Name ShowInSettings -Value 1 -PropertyType DWORD -Force | Out-Null

Write-Host "Registered AUMID '$AppId' with DisplayName='$DisplayName'"
