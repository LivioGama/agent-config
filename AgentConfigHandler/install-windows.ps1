# Install agent-config:// URL scheme handler for Windows

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir
$HandlerScript = Join-Path $ScriptDir "handle-deeplink.ps1"

# Create batch wrapper for PowerShell
$BatchContent = @"
@echo off
powershell -ExecutionPolicy Bypass -File "$HandlerScript" "%~1"
"@

$BatchPath = Join-Path $RepoDir "handle-deeplink.bat"
$BatchContent | Out-File -FilePath $BatchPath -Encoding ASCII

# Register URL scheme in registry
$RegistryPath = "HKCU:\Software\Classes\agent-config"
if (-not (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}

Set-ItemProperty -Path $RegistryPath -Name "(Default)" -Value "URL:agent-config" -Force
Set-ItemProperty -Path $RegistryPath -Name "URL Protocol" -Value "" -Force
Set-ItemProperty -Path $RegistryPath -Name "Content Type" -Value "application/x-agent-config" -Force

# Create shell command
$ShellPath = "$RegistryPath\shell"
if (-not (Test-Path $ShellPath)) {
    New-Item -Path $ShellPath -Force | Out-Null
}

Set-ItemProperty -Path $ShellPath -Name "(Default)" -Value "open" -Force

# Create open command
$OpenPath = "$ShellPath\open"
if (-not (Test-Path $OpenPath)) {
    New-Item -Path $OpenPath -Force | Out-Null
}

Set-ItemProperty -Path $OpenPath -Name "(Default)" -Value "Open Agent Config" -Force

# Create command
$CommandPath = "$OpenPath\command"
if (-not (Test-Path $CommandPath)) {
    New-Item -Path $CommandPath -Force | Out-Null
}

Set-ItemProperty -Path $CommandPath -Name "(Default)" -Value "`"$BatchPath`" `"%1`"" -Force

Write-Host "Installed agent-config:// handler for Windows"
Write-Host "Test with: start agent-config://https://example.com/rule.md"
