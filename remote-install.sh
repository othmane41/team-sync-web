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
