# Windows Development Toolchain - Bootstrap Script
# This script initializes the workspace environment on startup.
#
# Requirements Covered:
# - 11c.3: Toolchain manifest with bootstrap scripts

Write-Host "=== Windows Development Workspace Bootstrap ==="
Write-Host "Toolchain: windev-toolchain v1.0.0"
Write-Host "Started at: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

Write-Host ""
Write-Host "Setting up directories..."

$directories = @(
    "$env:USERPROFILE\Projects",
    "$env:USERPROFILE\bin",
    "$env:USERPROFILE\.config",
    "$env:USERPROFILE\Documents\Visual Studio 2022\Templates"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  Created: $dir"
    }
}

# ============================================================================
# GIT CONFIGURATION
# ============================================================================

Write-Host ""
Write-Host "Configuring Git..."

# Git will be configured via Coder external auth
# Only set defaults if not already configured
$gitEmail = git config --global user.email 2>$null
if (-not $gitEmail) {
    Write-Host "  Git user.email not configured - will be set via Coder external auth"
}

# Windows-specific Git settings
git config --global core.autocrlf true
git config --global init.defaultBranch main
git config --global core.editor "code --wait"

Write-Host "  Git configuration complete"

# ============================================================================
# ENVIRONMENT CONFIGURATION
# ============================================================================

Write-Host ""
Write-Host "Configuring environment..."

# Disable .NET telemetry
[Environment]::SetEnvironmentVariable("DOTNET_CLI_TELEMETRY_OPTOUT", "1", "User")
[Environment]::SetEnvironmentVariable("DOTNET_NOLOGO", "1", "User")

# Add user bin to PATH if not present
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$binPath = "$env:USERPROFILE\bin"
if ($userPath -notlike "*$binPath*") {
    [Environment]::SetEnvironmentVariable("PATH", "$binPath;$userPath", "User")
    Write-Host "  Added $binPath to PATH"
}

# ============================================================================
# TOOL VERIFICATION
# ============================================================================

Write-Host ""
Write-Host "Verifying toolchain installation..."

function Test-Tool {
    param(
        [string]$Name,
        [string]$Command,
        [string]$Pattern
    )
    
    try {
        $output = Invoke-Expression $Command 2>&1 | Out-String
        if ($output -match $Pattern) {
            $version = $Matches[0]
            Write-Host "  [OK] ${Name}: $version"
            return $true
        } else {
            Write-Host "  [WARN] ${Name}: Version pattern not matched"
            return $false
        }
    } catch {
        Write-Host "  [FAIL] ${Name}: Not found or error"
        return $false
    }
}

Test-Tool -Name ".NET SDK" -Command "dotnet --version" -Pattern "8\.\d+\.\d+"
Test-Tool -Name "PowerShell" -Command '$PSVersionTable.PSVersion.ToString()' -Pattern "7\.\d+"
Test-Tool -Name "Git" -Command "git --version" -Pattern "git version \d+\.\d+"
Test-Tool -Name "Azure CLI" -Command "az --version | Select-Object -First 1" -Pattern "azure-cli"
Test-Tool -Name "NuGet" -Command "nuget help | Select-Object -First 1" -Pattern "NuGet"

# Check Visual Studio
$vsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\Common7\IDE\devenv.exe"
if (Test-Path $vsPath) {
    Write-Host "  [OK] Visual Studio 2022 Professional: Installed"
} else {
    $vsEntPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\devenv.exe"
    if (Test-Path $vsEntPath) {
        Write-Host "  [OK] Visual Studio 2022 Enterprise: Installed"
    } else {
        Write-Host "  [WARN] Visual Studio 2022: Not found at expected path"
    }
}

# ============================================================================
# COMPLETION
# ============================================================================

Write-Host ""
Write-Host "=== Workspace Ready ==="
Write-Host "Completed at: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"
Write-Host ""
Write-Host "Quick start:"
Write-Host "  cd $env:USERPROFILE\Projects"
Write-Host "  git clone <repository>"
Write-Host "  devenv <solution.sln>"
Write-Host ""
