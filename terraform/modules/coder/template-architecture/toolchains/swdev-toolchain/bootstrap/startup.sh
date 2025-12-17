#!/bin/bash
# Software Development Toolchain - Bootstrap Script
# This script initializes the workspace environment on startup.
#
# Requirements Covered:
# - 11c.3: Toolchain manifest with bootstrap scripts
# - 11f.1: Portable template without infrastructure-specific details

set -e

echo "=== Software Development Workspace Bootstrap ==="
echo "Toolchain: swdev-toolchain v1.0.0"
echo "Started at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

echo "Setting up directories..."

# Create standard development directories
mkdir -p ~/projects
mkdir -p ~/bin
mkdir -p ~/.local/bin
mkdir -p ~/.profile.d
mkdir -p ~/.config

# Go workspace directories
mkdir -p ~/go/{bin,src,pkg}

# ============================================================================
# ENVIRONMENT CONFIGURATION
# ============================================================================

echo "Configuring environment..."

# Configure PATH additions
cat > ~/.profile.d/path.sh << 'EOF'
# Add local bin directories to PATH
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
EOF

# Configure Go environment
cat > ~/.profile.d/go.sh << 'EOF'
# Go environment
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
EOF

# Configure editor preferences
cat > ~/.profile.d/editor.sh << 'EOF'
# Editor configuration
export EDITOR="code --wait"
export VISUAL="code --wait"
EOF

# Configure locale
cat > ~/.profile.d/locale.sh << 'EOF'
# Locale settings
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
EOF

# ============================================================================
# GIT CONFIGURATION
# ============================================================================

echo "Checking Git configuration..."

# Git will be configured via Coder external auth
# Only set defaults if not already configured
if [ -z "$(git config --global core.editor 2>/dev/null)" ]; then
  git config --global core.editor "code --wait"
fi

if [ -z "$(git config --global init.defaultBranch 2>/dev/null)" ]; then
  git config --global init.defaultBranch main
fi

if [ -z "$(git config --global pull.rebase 2>/dev/null)" ]; then
  git config --global pull.rebase false
fi

# ============================================================================
# TOOL VERIFICATION
# ============================================================================

echo "Verifying toolchain installation..."

verify_tool() {
  local tool=$1
  local version_cmd=$2
  
  if command -v "$tool" &> /dev/null; then
    echo "  ✓ $tool: $($version_cmd 2>&1 | head -1)"
  else
    echo "  ✗ $tool: not found"
  fi
}

verify_tool "go" "go version"
verify_tool "node" "node --version"
verify_tool "python3" "python3 --version"
verify_tool "terraform" "terraform version"
verify_tool "kubectl" "kubectl version --client --short 2>/dev/null || kubectl version --client"
verify_tool "gh" "gh --version"
verify_tool "git" "git --version"
verify_tool "make" "make --version"
verify_tool "jq" "jq --version"

# ============================================================================
# CUSTOM STARTUP
# ============================================================================

# Source any custom startup scripts
if [ -f ~/.startup.d/custom.sh ]; then
  echo "Running custom startup script..."
  source ~/.startup.d/custom.sh
fi

# ============================================================================
# COMPLETION
# ============================================================================

echo ""
echo "=== Workspace Ready ==="
echo "Completed at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""
echo "Quick start:"
echo "  cd ~/projects"
echo "  git clone <repository>"
echo ""
