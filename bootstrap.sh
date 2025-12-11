#!/bin/bash
set -e

# Bootstrap script for dotfiles + Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/festeh/dotfiles/master/bootstrap.sh | bash -s <hostname>
# Or: ./bootstrap.sh <hostname>

HOSTNAME="${1:-$(hostname)}"
DOTFILES_DIR="$HOME/dotfiles"
INSTALLER_DIR="$HOME/Installer"
GITHUB_USER="festeh"

echo "==> Bootstrapping dotfiles for host: $HOSTNAME"

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

# Check if host config exists
if [ ! -f "$DOTFILES_DIR/hosts/$HOSTNAME/config.toml" ]; then
    echo "Error: No config found for host '$HOSTNAME'"
    echo "Available hosts:"
    ls -1 "$DOTFILES_DIR/hosts/"
    exit 1
fi

# Run installer
echo "==> Running installer for $HOSTNAME..."
cd "$INSTALLER_DIR"
./installer -c config -h "$HOSTNAME"

echo ""
echo "==> Bootstrap complete!"
echo "    You may need to restart your shell or run: source ~/.zshrc"
