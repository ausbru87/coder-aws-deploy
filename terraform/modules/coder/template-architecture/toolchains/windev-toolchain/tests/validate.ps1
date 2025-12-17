# Windows Development Toolchain - Validation Tests
# This script validates that the toolchain is correctly configured.
#
# Requirements Covered:
# - 11f.3: Validate templates locally using lint and contract checks

Write-Host "=== Toolchain Validation Tests ==="
Write-Host "Toolchain: windev-toolchain v1.0.0"
Write-Host ""

$Pass = 0
$Fail = 0

function Test-Requirement {
    param(
        [string]$Name,
        [string]$Command,
        [string]$Pattern
    )
    
    Write-Host -NoNewline "Testing $Name... "
    
    try {
        $output = Invoke-Expression $Command 2>&1 | Out-String
        if ($output -match $Pattern) {
            Write-Host "PASS"
            $script:Pass++
            return $true
        } else {
            Write-Host "FAIL (pattern not matched)"
            Write-Host "  Expected pattern: $Pattern"
            Write-Host "  Got: $($output.Trim())"
            $script:Fail++
            return $false
        }
    } catch {
        Write-Host "FAIL (command failed)"
        Write-Host "  Command: $Command"
        Write-Host "  Error: $_"
        $script:Fail++
        return $false
    }
}

# ============================================================================
# LANGUAGE TESTS
# ============================================================================

Write-Host "--- Language Tests ---"

Test-Requirement -Name ".NET SDK version" -Command "dotnet --version" -Pattern "8\.\d+"
Test-Requirement -Name "PowerShell version" -Command 'pwsh --version' -Pattern "PowerShell 7\."

# ============================================================================
# TOOL TESTS
# ============================================================================

Write-Host ""
Write-Host "--- Tool Tests ---"

Test-Requirement -Name "Git" -Command "git --version" -Pattern "git version"
Test-Requirement -Name "Azure CLI" -Command "az --version | Select-Object -First 1" -Pattern "azure-cli"
Test-Requirement -Name "NuGet" -Command "nuget help | Select-Object -First 1" -Pattern "NuGet"

# Visual Studio check
Write-Host -NoNewline "Testing Visual Studio 2022... "
$vsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\Common7\IDE\devenv.exe"
$vsEntPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\devenv.exe"

if ((Test-Path $vsPath) -or (Test-Path $vsEntPath)) {
    Write-Host "PASS"
    $Pass++
} else {
    Write-Host "FAIL (not found)"
    $Fail++
}

# ============================================================================
# ENVIRONMENT TESTS
# ============================================================================

Write-Host ""
Write-Host "--- Environment Tests ---"

Write-Host -NoNewline "Testing user profile writable... "
$testFile = "$env:USERPROFILE\test_write_$PID"
try {
    New-Item -ItemType File -Path $testFile -Force | Out-Null
    Remove-Item $testFile -Force
    Write-Host "PASS"
    $Pass++
} catch {
    Write-Host "FAIL"
    $Fail++
}

Write-Host -NoNewline "Testing Projects directory exists... "
if (Test-Path "$env:USERPROFILE\Projects") {
    Write-Host "PASS"
    $Pass++
} else {
    Write-Host "FAIL"
    $Fail++
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-Host "=== Validation Summary ==="
Write-Host "Passed: $Pass"
Write-Host "Failed: $Fail"
Write-Host ""

if ($Fail -gt 0) {
    Write-Host "VALIDATION FAILED"
    exit 1
} else {
    Write-Host "VALIDATION PASSED"
    exit 0
}
