<#
.SYNOPSIS
    shiprocket-api-skill installer for Windows (PowerShell 5+).

.DESCRIPTION
    Two ways to run:

    1. From inside a cloned checkout:
         .\install.ps1

    2. One-liner (replace REPO_URL before publishing):
         iwr -useb https://raw.githubusercontent.com/aditya-m-bharadwaj/shiprocket-api-skill/main/install.ps1 | iex

.PARAMETER Prefix
    Directory the launcher script is installed into. Default: $env:USERPROFILE\.local\bin

.PARAMETER ShiprocketCtlHome
    Where the repo is cloned. Default: $env:USERPROFILE\.local\share\shiprocket-api-skill

.PARAMETER Repo
    Git URL to clone. Default: REPO_URL placeholder (override via env or arg).

.PARAMETER Ref
    Branch/tag/SHA to check out. Default: main.

.PARAMETER InstallSkill
    Pass to also install the Claude skill into $env:USERPROFILE\.claude\skills\shiprocket-api-skill\.

.PARAMETER RunSetup
    Pass to immediately run `shiprocket-api-skill setup` after install (credential entry is hidden).

.PARAMETER NoSetup
    Pass to skip the post-install prompt entirely.
#>

[CmdletBinding()]
param(
    [string]$Prefix = (Join-Path $env:USERPROFILE ".local\bin"),
    [string]$ShiprocketCtlHome = (Join-Path $env:USERPROFILE ".local\share\shiprocket-api-skill"),
    [string]$Repo = "https://github.com/aditya-m-bharadwaj/shiprocket-api-skill.git",
    [string]$Ref = "main",
    [switch]$InstallSkill,
    [switch]$RunSetup,
    [switch]$NoSetup
)

$ErrorActionPreference = "Stop"

function Write-Say  { param($Msg) Write-Host "[install] $Msg" -ForegroundColor Cyan }
function Write-Warn { param($Msg) Write-Host "[warn] $Msg"    -ForegroundColor Yellow }
function Die        { param($Msg) Write-Host "[error] $Msg"   -ForegroundColor Red; exit 1 }

# 1. Locate or clone -----------------------------------------------------------
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (Test-Path (Join-Path $ScriptDir "bin\shiprocket-api-skill")) {
    $Src = $ScriptDir
    Write-Say "Using current checkout: $Src"
} else {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die "git is required but not installed." }
    if (Test-Path (Join-Path $ShiprocketCtlHome ".git")) {
        Write-Say "Updating existing checkout at $ShiprocketCtlHome"
        git -C $ShiprocketCtlHome fetch --quiet --tags | Out-Null
        git -C $ShiprocketCtlHome checkout --quiet $Ref | Out-Null
        try { git -C $ShiprocketCtlHome pull --quiet --ff-only | Out-Null } catch { Write-Warn "could not fast-forward; continuing on $Ref" }
    } else {
        Write-Say "Cloning $Repo -> $ShiprocketCtlHome (ref=$Ref)"
        New-Item -ItemType Directory -Force -Path (Split-Path $ShiprocketCtlHome) | Out-Null
        git clone --quiet --branch $Ref $Repo $ShiprocketCtlHome
        if ($LASTEXITCODE -ne 0) { Die "git clone failed. Use -Repo to override if you forked." }
    }
    $Src = $ShiprocketCtlHome
}
$Bin = Join-Path $Src "bin\shiprocket-api-skill"
if (-not (Test-Path $Bin)) { Die "bin\shiprocket-api-skill not found in $Src" }

# 2. Verify Python 3.8+ --------------------------------------------------------
$Py = $null
foreach ($cand in @("python", "python3", "py")) {
    $cmd = Get-Command $cand -ErrorAction SilentlyContinue
    if (-not $cmd) { continue }
    $v = & $cmd -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>$null
    if ($v -match "^3\.(8|9|1[0-9]|[2-9][0-9])$") { $Py = $cmd.Source; break }
}
if (-not $Py) { Die "Python 3.8+ is required. Install from https://python.org or `winget install Python.Python.3.12`." }
Write-Say "Python: $Py ($(& $Py --version 2>&1))"

# 3. Create launcher (.cmd shim that runs the script via Python) --------------
New-Item -ItemType Directory -Force -Path $Prefix | Out-Null
$Launcher = Join-Path $Prefix "shiprocket-api-skill.cmd"
@"
@echo off
"$Py" "$Bin" %*
"@ | Set-Content -Path $Launcher -Encoding ASCII
Write-Say "Launcher: $Launcher"

# 4. PATH check ---------------------------------------------------------------
$onPath = ($env:Path -split ';') -contains $Prefix
if (-not $onPath) {
    Write-Warn "$Prefix is not on PATH for the current session."
    Write-Warn "To add permanently for the current user:"
    Write-Warn "    [Environment]::SetEnvironmentVariable('Path', `"`$env:Path;$Prefix`", 'User')"
    Write-Warn "Then restart your shell."
}

# 5. Optional: Claude skill ---------------------------------------------------
$SkillSrc = Join-Path $Src ".claude\skills\shiprocket-api-skill\SKILL.md"
$SkillDstDir = Join-Path $env:USERPROFILE ".claude\skills\shiprocket-api-skill"
if (Test-Path $SkillSrc) {
    $do = $InstallSkill
    if (-not $do) {
        $ans = Read-Host "Install the Claude skill to $SkillDstDir ? [y/N]"
        if ($ans -match '^(y|yes)$') { $do = $true }
    }
    if ($do) {
        New-Item -ItemType Directory -Force -Path $SkillDstDir | Out-Null
        Copy-Item -Path $SkillSrc -Destination (Join-Path $SkillDstDir "SKILL.md") -Force
        Write-Say "Skill installed: $(Join-Path $SkillDstDir 'SKILL.md')"
    }
}

# 6. Optional: run `shiprocket-api-skill setup` so the user can enter credentials now ---
#
# Credential entry happens inside Python (visible email prompt + getpass for
# password), so input is hidden and credentials never appear in this script's
# variables, history, or argv.
$doSetup = $false
if ($NoSetup) {
    $doSetup = $false
} elseif ($RunSetup) {
    $doSetup = $true
} else {
    $ans = Read-Host "Run ``shiprocket-api-skill setup`` now to add your API-user credentials? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($ans) -or $ans -match '^(y|yes)$') {
        $doSetup = $true
    }
}

if ($doSetup) {
    Write-Say "Launching: shiprocket-api-skill setup"
    & $Launcher setup
}

# 7. Done ---------------------------------------------------------------------
Write-Host ""
Write-Say "Installed. Next steps:"
if (-not $doSetup) {
    Write-Say "  1. Run:  shiprocket-api-skill setup           # enter API-user email + password (password hidden)"
    Write-Say "  2. Run:  shiprocket-api-skill whoami          # verify auth"
} else {
    Write-Say "  1. Run:  shiprocket-api-skill whoami          # verify auth"
}
Write-Say "  - To change credentials later:  shiprocket-api-skill setup        (or 'rotate-token')"
Write-Say "  - To remove the local JWT:      shiprocket-api-skill uninstall-token --yes"
Write-Say "  - JWT lifetime is ~10 days. Re-run setup when whoami returns 401."
Write-Say "  - Read: $Src\README.md"
