#!/bin/bash
set -e

# Bootstrap script for dotfiles + Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/festeh/dotfiles/master/bootstrap.sh | bash

DOTFILES_DIR="$HOME/dotfiles"
INSTALLER_DIR="$HOME/Installer"
GITHUB_USER="festeh"

echo "==> Bootstrapping dotfiles..."

# Check for git
if ! command -v git &> /dev/null; then
    echo "Error: git is required. Install it first."
    echo "  On Debian/Ubuntu: sudo apt install git"
    echo "  On Arch: sudo pacman -S git"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *)
        echo "Error: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac
echo "==> Detected architecture: $ARCH"

# Clone dotfiles if not present
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "==> Cloning dotfiles..."
    git clone "https://github.com/$GITHUB_USER/dotfiles.git" "$DOTFILES_DIR"
else
    echo "==> Dotfiles already present, pulling latest..."
    git -C "$DOTFILES_DIR" pull
fi

# Create Installer directory
mkdir -p "$INSTALLER_DIR"

# Download installer binary
INSTALLER_URL="https://github.com/$GITHUB_USER/Installer/releases/latest/download/installer-linux-$ARCH"
echo "==> Downloading installer from $INSTALLER_URL..."
curl -fsSL "$INSTALLER_URL" -o "$INSTALLER_DIR/installer"
chmod +x "$INSTALLER_DIR/installer"

# Run installer (auto-detects hostname)
echo "==> Running installer..."
cd "$INSTALLER_DIR"
./installer -c install
./installer -c config

echo ""
echo "==> Bootstrap complete!"
echo "    You may need to restart your shell or run: source ~/.zshrc"
