#!/bin/bash
# Software Development Toolchain - Validation Tests
# This script validates that the toolchain is correctly configured.
#
# Requirements Covered:
# - 11f.3: Validate templates locally using lint and contract checks

set -e

echo "=== Toolchain Validation Tests ==="
echo "Toolchain: swdev-toolchain v1.0.0"
echo ""

PASS=0
FAIL=0

# Test function
run_test() {
  local name=$1
  local command=$2
  local expected_pattern=$3
  
  echo -n "Testing $name... "
  
  if output=$($command 2>&1); then
    if echo "$output" | grep -qE "$expected_pattern"; then
      echo "PASS"
      ((PASS++))
    else
      echo "FAIL (pattern not matched)"
      echo "  Expected pattern: $expected_pattern"
      echo "  Got: $output"
      ((FAIL++))
    fi
  else
    echo "FAIL (command failed)"
    echo "  Command: $command"
    echo "  Output: $output"
    ((FAIL++))
  fi
}

# ============================================================================
# LANGUAGE TESTS
# ============================================================================

echo "--- Language Tests ---"

run_test "Go version" "go version" "go1\.23"
run_test "Node.js version" "node --version" "v22\."
run_test "Python version" "python3 --version" "Python 3\.12"

# ============================================================================
# TOOL TESTS
# ============================================================================

echo ""
echo "--- Tool Tests ---"

run_test "Terraform" "terraform version" "Terraform v"
run_test "kubectl" "kubectl version --client" "Client Version"
run_test "GitHub CLI" "gh --version" "gh version"
run_test "Git" "git --version" "git version"
run_test "Make" "make --version" "GNU Make"
run_test "jq" "jq --version" "jq-"
run_test "yq" "yq --version" "yq"

# Optional tools (don't fail if not installed)
echo ""
echo "--- Optional Tool Tests ---"

if command -v docker &> /dev/null; then
  run_test "Docker CLI" "docker --version" "Docker version"
else
  echo "Docker CLI: SKIPPED (not installed)"
fi

if command -v aws &> /dev/null; then
  run_test "AWS CLI" "aws --version" "aws-cli"
else
  echo "AWS CLI: SKIPPED (not installed)"
fi

if command -v helm &> /dev/null; then
  run_test "Helm" "helm version --short" "v3\."
else
  echo "Helm: SKIPPED (not installed)"
fi

# ============================================================================
# ENVIRONMENT TESTS
# ============================================================================

echo ""
echo "--- Environment Tests ---"

echo -n "Testing GOPATH set... "
if [ -n "$GOPATH" ]; then
  echo "PASS ($GOPATH)"
  ((PASS++))
else
  echo "FAIL (GOPATH not set)"
  ((FAIL++))
fi

echo -n "Testing home directory writable... "
if touch ~/test_write_$$ && rm ~/test_write_$$; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL"
  ((FAIL++))
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "=== Validation Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ $FAIL -gt 0 ]; then
  echo "VALIDATION FAILED"
  exit 1
else
  echo "VALIDATION PASSED"
  exit 0
fi
