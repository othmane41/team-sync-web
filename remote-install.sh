#!/bin/bash
# Dynamic Horizon Sync — one-liner installer
# Usage: curl -sL <url>/remote-install.sh | bash
set -e

APP_NAME="Dynamic Horizon Sync"
REPO="https://github.com/othmane41/team-sync-web.git"
INSTALL_DIR="/Applications"
BUILD_DIR=$(mktemp -d)

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${BLUE}==>${NC} ${BOLD}$1${NC}"; }
ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
fail() { echo -e "${RED}  ✗ $1${NC}"; exit 1; }

cleanup() { rm -rf "$BUILD_DIR"; }
trap cleanup EXIT

echo ""
echo -e "${BOLD}  ╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}  ║      Dynamic Horizon Sync            ║${NC}"
echo -e "${BOLD}  ║      Remote Installer v1.0.0         ║${NC}"
echo -e "${BOLD}  ╚══════════════════════════════════════╝${NC}"
echo ""
echo "  Architecture: $(uname -m)"
echo "  macOS: $(sw_vers -productVersion)"
echo ""

# ── Prerequisites ────────────────────────────────────────────
log "Checking prerequisites..."

if [[ "$(uname)" != "Darwin" ]]; then
    fail "macOS only."
fi

# Xcode CLI tools (provides swiftc + git)
if ! xcode-select -p &>/dev/null; then
    log "Installing Xcode Command Line Tools (required)..."
    xcode-select --install
    echo "  Waiting for installation to complete..."
    until xcode-select -p &>/dev/null; do sleep 5; done
fi
ok "Xcode CLI tools"

# Homebrew
if ! command -v brew &>/dev/null; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
fi
ok "Homebrew"

# Go
if ! command -v go &>/dev/null; then
    log "Installing Go..."
    brew install go
fi
ok "Go $(go version | grep -oE 'go[0-9]+\.[0-9]+' | head -1)"

# rsync
if ! command -v rsync &>/dev/null; then
    brew install rsync
fi
ok "rsync"

# ── Get source ───────────────────────────────────────────────
log "Downloading source code..."

if [ -d "$BUILD_DIR/src" ]; then
    rm -rf "$BUILD_DIR/src"
fi

# Try git clone first, fallback to local copy if repo not available yet
if git clone --depth 1 "$REPO" "$BUILD_DIR/src" 2>/dev/null; then
    ok "Cloned from $REPO"
else
    # Fallback: look for local source
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/go.mod" ]; then
        cp -R "$SCRIPT_DIR" "$BUILD_DIR/src"
        ok "Using local source"
    else
        fail "Cannot find source code. Push the repo to $REPO first."
    fi
fi

cd "$BUILD_DIR/src"

# ── Build ────────────────────────────────────────────────────
log "Building Go server (native $(uname -m))..."
go build -o team-sync-web .
ok "Server compiled"

log "Generating icon..."
cd macos && bash gen-icon.sh 2>/dev/null
cd "$BUILD_DIR/src"
ok "Icon ready"

log "Building native macOS app..."
swiftc -O -o macos/TeamSync macos/main.swift \
    -framework Cocoa -framework WebKit
ok "Swift wrapper compiled"

# ── Assemble .app ────────────────────────────────────────────
log "Assembling ${APP_NAME}.app..."
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"
cp macos/Info.plist "${APP_NAME}.app/Contents/"
cp macos/TeamSync  "${APP_NAME}.app/Contents/MacOS/"
cp team-sync-web   "${APP_NAME}.app/Contents/MacOS/"
cp macos/AppIcon.icns "${APP_NAME}.app/Contents/Resources/"
chmod +x "${APP_NAME}.app/Contents/MacOS/TeamSync"
chmod +x "${APP_NAME}.app/Contents/MacOS/team-sync-web"

# Ad-hoc sign to avoid Gatekeeper issues
codesign --force --deep --sign - "${APP_NAME}.app" 2>/dev/null && \
    ok "App signed (ad-hoc)" || \
    ok "App assembled (unsigned)"

# ── Install ──────────────────────────────────────────────────
log "Installing to ${INSTALL_DIR}..."

if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
    # Kill if running
    pkill -f "team-sync-web" 2>/dev/null || true
    pkill -f "TeamSync" 2>/dev/null || true
    sleep 1
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
    ok "Replaced previous version"
fi

cp -R "${APP_NAME}.app" "${INSTALL_DIR}/"
ok "Installed to ${INSTALL_DIR}/${APP_NAME}.app"

mkdir -p "$HOME/.dh-sync"

# ── SSH Setup ───────────────────────────────────────────────
log "Setting up SSH..."

# 1. Generate SSH key if not present
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY" ]; then
    log "Generating SSH key..."
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "$(whoami)@$(hostname)"
    ok "SSH key created: $SSH_KEY"
else
    ok "SSH key already exists: $SSH_KEY"
fi

# 2. Enable Remote Login (macOS SSH server)
if systemsetup -getremotelogin 2>/dev/null | grep -qi "on"; then
    ok "Remote Login already enabled"
else
    echo ""
    echo -e "  ${BOLD}Remote Login (SSH server) must be enabled${NC}"
    echo "  so that other machines can connect to yours."
    echo ""
    read -p "  Enable Remote Login now? (requires admin password) [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo systemsetup -setremotelogin on
        ok "Remote Login enabled"
    else
        echo -e "  ${RED}⚠${NC}  Skipped. Enable manually: System Settings → General → Sharing → Remote Login"
    fi
fi

# 3. Show local IP for teammates
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")
echo ""
echo -e "  ${BOLD}Your local IP:${NC} $LOCAL_IP"
echo -e "  ${BOLD}Your username:${NC} $(whoami)"
echo ""
echo -e "  Share this with your teammates so they can add your machine:"
echo -e "    ${BOLD}$(whoami)@${LOCAL_IP}${NC}"
echo ""

# 4. Send SSH key to collaborators
echo -e "${BOLD}  ── Send your SSH key to teammates ──${NC}"
echo ""
echo "  Enter the IP addresses of your teammates (one per line)."
echo "  Leave empty and press Enter when done."
echo ""

while true; do
    read -p "  Teammate IP (or Enter to skip): " PEER_IP
    [ -z "$PEER_IP" ] && break

    read -p "  Username on $PEER_IP [$(whoami)]: " PEER_USER
    PEER_USER="${PEER_USER:-$(whoami)}"

    read -p "  SSH port for $PEER_IP [22]: " PEER_PORT
    PEER_PORT="${PEER_PORT:-22}"

    echo -e "  Sending key to ${BOLD}${PEER_USER}@${PEER_IP}:${PEER_PORT}${NC}..."
    echo "  (You may be asked for ${PEER_USER}'s password on that machine)"
    echo ""

    if ssh-copy-id -p "$PEER_PORT" "${PEER_USER}@${PEER_IP}" 2>/dev/null; then
        ok "Key sent to ${PEER_USER}@${PEER_IP}"
    else
        # Fallback: manual ssh-copy-id
        PUB_KEY=$(cat "${SSH_KEY}.pub")
        if ssh -p "$PEER_PORT" -o StrictHostKeyChecking=accept-new \
            "${PEER_USER}@${PEER_IP}" \
            "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '${PUB_KEY}' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" 2>/dev/null; then
            ok "Key sent to ${PEER_USER}@${PEER_IP} (manual)"
        else
            echo -e "  ${RED}⚠${NC}  Failed to send key to ${PEER_USER}@${PEER_IP}"
            echo "     Try manually: ssh-copy-id -p ${PEER_PORT} ${PEER_USER}@${PEER_IP}"
        fi
    fi
    echo ""
done

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  ✓ Installation complete!${NC}"
echo ""
echo "  Launch: Spotlight → \"Dynamic Horizon Sync\""
echo "         or: open -a \"Dynamic Horizon Sync\""
echo ""

# Launch
open "${INSTALL_DIR}/${APP_NAME}.app"
ok "Launched!"
