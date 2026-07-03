# Handle agent-rules:// deeplinks for Windows

param(
    [Parameter(Mandatory=$true)]
    [string]$Deeplink
)

# Extract URL from the deeplink
if (-not $Deeplink.StartsWith("agent-rules://")) {
    Write-Error "Error: Invalid deeplink format"
    exit 1
}

$Url = $Deeplink.Substring("agent-rules://".Length)

# Validate URL
if ($Url -notmatch "^https?://") {
    Write-Error "Error: Invalid URL format. Expected agent-rules://https://..."
    exit 1
}

# Determine if this is a skill or rule based on URL path
if ($Url -match "/skills/[^/]+/SKILL.md$") {
    # This is a skill
    $IsSkill = $true
    $DestDir = Join-Path $RepoDir ".agent-config\skills"
} else {
    # This is a rule
    $IsSkill = $false
    $DestDir = Join-Path $RepoDir ".agent-config\rules"
}

# Paths
$RepoDir = Split-Path -Parent $PSScriptRoot
$BuildScript = Join-Path $RepoDir "build.sh"

# Ensure destination directory exists
if (-not (Test-Path $DestDir)) {
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
}

# Extract path structure from URL
$UrlPath = ($Url -split "https?://[^/]+/")[-1]

# Determine destination path
if ($IsSkill) {
    # Extract skill name from path like "skills/my-skill/SKILL.md"
    if ($UrlPath -match "skills/([^/]+)/SKILL.md") {
        $SkillName = $Matches[1]
        $DestPath = Join-Path $DestDir "$SkillName\SKILL.md"
        $SkillDir = Split-Path $DestPath -Parent
        if (-not (Test-Path $SkillDir)) {
            New-Item -ItemType Directory -Path $SkillDir -Force | Out-Null
        }
    } else {
        Write-Error "Error: Invalid skill path format"
        exit 1
    }
} else {
    # Extract filename for rules
    $Filename = Split-Path $Url -Leaf
    $DestPath = Join-Path $DestDir $Filename
}

# Download the file
Write-Host "Downloading $(if ($IsSkill) { 'skill' } else { 'rule' }) from $Url..."
try {
    Invoke-WebRequest -Uri $Url -OutFile $DestPath -UseBasicParsing
} catch {
    Write-Error "Error: Download failed"
    exit 1
}

if ((Get-Item $DestPath).Length -eq 0) {
    Write-Error "Error: Downloaded file is empty"
    Remove-Item $DestPath -Force
    exit 1
}

Write-Host "Saved to $DestPath"

# Run build script
Write-Host "Running build.sh..."
Push-Location $RepoDir
try {
    bash $BuildScript
} catch {
    Write-Error "Error: build.sh failed"
    exit 1
} finally {
    Pop-Location
}

Write-Host "Done! $(if ($IsSkill) { 'Skill' } else { 'Rule' }) installed and synced."