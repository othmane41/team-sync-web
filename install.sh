#!/bin/bash
set -e

APP_NAME="Dynamic Horizon Sync"
INSTALL_DIR="/Applications"
REPO_URL="https://github.com/dynamic-horizon/team-sync-web"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${BLUE}==>${NC} ${BOLD}$1${NC}"; }
ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
fail() { echo -e "${RED}  ✗ $1${NC}"; exit 1; }

echo ""
echo -e "${BOLD}  ╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}  ║      Dynamic Horizon Sync            ║${NC}"
echo -e "${BOLD}  ║      Installer v1.0.0                ║${NC}"
echo -e "${BOLD}  ╚══════════════════════════════════════╝${NC}"
echo ""

# ── Check macOS ──────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
    fail "This installer is for macOS only."
fi
ok "macOS detected ($(sw_vers -productVersion))"

# ── Check architecture ───────────────────────────────────────
ARCH=$(uname -m)
ok "Architecture: $ARCH"

# ── Check dependencies ───────────────────────────────────────
log "Checking dependencies..."

# rsync
if command -v rsync &>/dev/null; then
    RSYNC_VER=$(rsync --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    ok "rsync $RSYNC_VER"
else
    fail "rsync not found. Install with: brew install rsync"
fi

# SSH
if command -v ssh &>/dev/null; then
    ok "ssh available"
else
    fail "ssh not found."
fi

# Go compiler
GO_BIN=""
if command -v go &>/dev/null; then
    GO_BIN="go"
elif [ -x /opt/homebrew/bin/go ]; then
    GO_BIN="/opt/homebrew/bin/go"
elif [ -x /usr/local/go/bin/go ]; then
    GO_BIN="/usr/local/go/bin/go"
fi

if [ -z "$GO_BIN" ]; then
    log "Go not found. Installing via Homebrew..."
    if ! command -v brew &>/dev/null; then
        fail "Neither Go nor Homebrew found. Install Go: https://go.dev/dl/"
    fi
    brew install go
    GO_BIN=$(brew --prefix go)/bin/go
fi
GO_VER=$($GO_BIN version | grep -oE 'go[0-9]+\.[0-9]+' | head -1)
ok "Go $GO_VER ($GO_BIN)"

# Swift compiler
if command -v swiftc &>/dev/null; then
    SWIFT_VER=$(swiftc --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    ok "Swift $SWIFT_VER"
else
    fail "Swift not found. Install Xcode Command Line Tools: xcode-select --install"
fi

# ── Build ────────────────────────────────────────────────────
log "Building Go server..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

$GO_BIN build -o team-sync-web .
ok "Go binary compiled"

log "Generating app icon..."
cd macos && bash gen-icon.sh 2>/dev/null
cd "$SCRIPT_DIR"
ok "Icon generated"

log "Compiling native macOS wrapper..."
swiftc -O -o macos/TeamSync macos/main.swift \
    -framework Cocoa -framework WebKit
ok "Swift binary compiled"

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
ok "App bundle created"

# ── Install to /Applications ─────────────────────────────────
log "Installing to ${INSTALL_DIR}..."

if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
    echo -e "  ${RED}⚠${NC}  ${APP_NAME}.app already exists in ${INSTALL_DIR}"
    read -p "  Overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Skipping /Applications install. App available at:"
        echo "  ${SCRIPT_DIR}/${APP_NAME}.app"
        echo ""
        exit 0
    fi
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

cp -R "${APP_NAME}.app" "${INSTALL_DIR}/"
ok "Installed to ${INSTALL_DIR}/${APP_NAME}.app"

# ── Create data directory ────────────────────────────────────
mkdir -p "$HOME/.dh-sync"
ok "Config directory: ~/.dh-sync/"

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  ✓ Installation complete!${NC}"
echo ""
echo "  Launch from:"
echo "    • Spotlight  →  search \"Dynamic Horizon Sync\""
echo "    • Finder     →  Applications → Dynamic Horizon Sync"
echo "    • Terminal    →  open -a \"Dynamic Horizon Sync\""
echo ""
echo "  Uninstall:"
echo "    rm -rf /Applications/Dynamic\\ Horizon\\ Sync.app ~/.dh-sync"
echo ""

# ── Offer to launch ──────────────────────────────────────────
read -p "  Launch now? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    open "${INSTALL_DIR}/${APP_NAME}.app"
    ok "Launched!"
fi
