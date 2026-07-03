# Handle agent-config:// deeplinks for Windows

param(
    [Parameter(Mandatory=$true)]
    [string]$Deeplink
)

$ErrorActionPreference = "Stop"

# Extract URL from the deeplink
$Scheme = "agent-config://"
if (-not $Deeplink.StartsWith($Scheme)) {
    Write-Error "Error: Invalid deeplink format. Expected ${Scheme}https://..."
    exit 1
}

$Url = $Deeplink.Substring($Scheme.Length)
if ($Url -notmatch "^https://") {
    $Url = [Uri]::UnescapeDataString($Url)
}

# Validate URL
if ($Url -notmatch "^https://") {
    Write-Error "Error: Invalid URL format. Expected ${Scheme}https://..."
    exit 1
}

$HomeDir = [Environment]::GetFolderPath("UserProfile")
if ($env:AGENT_CONFIG_REPO_DIR) {
    $RepoDir = $env:AGENT_CONFIG_REPO_DIR
} elseif (Test-Path (Join-Path $PSScriptRoot "build.sh")) {
    $RepoDir = $PSScriptRoot
} elseif (Test-Path (Join-Path $HomeDir "agent-config")) {
    $RepoDir = Join-Path $HomeDir "agent-config"
} else {
    $RepoDir = Join-Path $HomeDir "agent-config"
}

$ConfigRoot = if ($env:AGENT_CONFIG_ROOT) {
    $env:AGENT_CONFIG_ROOT
} else {
    Join-Path $HomeDir ".agent-config"
}

$BuildScript = Join-Path $RepoDir "build.sh"

# Determine if this is a skill or rule based on URL path
$Uri = [Uri]$Url
$UrlPath = $Uri.AbsolutePath.TrimStart("/")
$IsSkill = $UrlPath -match "(^|/)skills/([A-Za-z0-9][A-Za-z0-9._-]*)/SKILL\.md$"
$IsAgentConfig = $UrlPath -match "(^|/)\.agent-config/AGENTS\.md$"
$DestDir = if ($IsSkill) {
    Join-Path $ConfigRoot "skills"
} elseif ($IsAgentConfig) {
    $ConfigRoot
} else {
    Join-Path $ConfigRoot "rules"
}

# Ensure destination directory exists
if (-not (Test-Path $DestDir)) {
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
}

# Determine destination path
if ($IsSkill) {
    $SkillName = $Matches[2]
    $DestPath = Join-Path $DestDir "$SkillName\SKILL.md"
    $SkillDir = Split-Path $DestPath -Parent
    if (-not (Test-Path $SkillDir)) {
        New-Item -ItemType Directory -Path $SkillDir -Force | Out-Null
    }
} elseif ($IsAgentConfig) {
    $DestPath = Join-Path $DestDir "AGENTS.md"
} else {
    $Filename = Split-Path $Uri.AbsolutePath -Leaf
    if ($Filename -notmatch "^[A-Za-z0-9][A-Za-z0-9._-]*\.md$") {
        Write-Error "Error: Invalid rule filename. Expected a safe .md basename"
        exit 1
    }
    $DestPath = Join-Path $DestDir $Filename
}

# Download the file
$InstallKind = if ($IsSkill) { "skill" } elseif ($IsAgentConfig) { "agent config" } else { "rule" }
Write-Host "Downloading $InstallKind from $Url..."
$TempPath = Join-Path (Split-Path $DestPath -Parent) "$([IO.Path]::GetFileName($DestPath)).download.$([guid]::NewGuid()).tmp"
try {
    Invoke-WebRequest -Uri $Url -OutFile $TempPath -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Error "Error: Download failed: $_"
    exit 1
}

if (-not (Test-Path -LiteralPath $TempPath)) {
    Write-Error "Error: Download did not create a file"
    exit 1
}

if ((Get-Item -LiteralPath $TempPath).Length -eq 0) {
    Write-Error "Error: Downloaded file is empty"
    Remove-Item -LiteralPath $TempPath -Force
    exit 1
}

Move-Item -LiteralPath $TempPath -Destination $DestPath -Force
Write-Host "Saved to $DestPath"

# Run build script
if (-not (Test-Path $BuildScript)) {
    Write-Error "Error: build.sh not found at $BuildScript"
    exit 1
}

Write-Host "Running build.sh..."
Push-Location $RepoDir
try {
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $bash) {
        Write-Error "Error: bash not found. Install WSL or Git Bash to run build.sh."
        exit 1
    }
    $env:AGENT_CONFIG_ROOT = $ConfigRoot
    & $bash.Source $BuildScript
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: build.sh failed with exit code $LASTEXITCODE"
        exit 1
    }
} catch {
    Write-Error "Error: build.sh failed: $_"
    exit 1
} finally {
    Pop-Location
}

$DoneKind = if ($IsSkill) { "Skill" } elseif ($IsAgentConfig) { "Agent Config" } else { "Rule" }
Write-Host "Done! $DoneKind installed and synced."
