#!/bin/bash
set -e

APP_NAME="Dynamic Horizon Sync"
DMG_NAME="Dynamic-Horizon-Sync"
VERSION="1.0.0"
DMG_FINAL="${DMG_NAME}-${VERSION}.dmg"
DMG_TEMP="${DMG_NAME}-temp.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"
STAGING_DIR=".dmg-staging"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${BLUE}==>${NC} ${BOLD}$1${NC}"; }
ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
fail() { echo -e "${RED}  ✗ $1${NC}"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# ── Check app exists ─────────────────────────────────────────
if [ ! -d "${APP_NAME}.app" ]; then
    fail "${APP_NAME}.app not found. Run 'make app' first."
fi
ok "Found ${APP_NAME}.app"

# ── Clean previous builds ────────────────────────────────────
rm -rf "$STAGING_DIR" "$DMG_TEMP" "$DMG_FINAL"

# ── Create staging directory ─────────────────────────────────
log "Preparing DMG contents..."
mkdir -p "$STAGING_DIR"
cp -R "${APP_NAME}.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create a simple README
cat > "$STAGING_DIR/README.txt" << 'EOF'
Dynamic Horizon Sync
====================

Installation:
  Drag "Dynamic Horizon Sync" into the Applications folder.

First launch:
  macOS may ask to confirm opening an app from an unidentified developer.
  Go to System Settings → Privacy & Security → click "Open Anyway".

Requirements:
  • macOS 12+
  • rsync (pre-installed on macOS, or: brew install rsync)
  • SSH keys configured for your team machines

Usage:
  1. Launch the app
  2. Add your team machines (Machines → Add)
  3. Test SSH connectivity
  4. Transfer files with push/pull

Uninstall:
  Drag the app from Applications to Trash.
  Optionally delete config: rm -rf ~/.dh-sync

EOF
ok "Staging directory ready"

# ── Create DMG ───────────────────────────────────────────────
log "Creating DMG image..."

# Calculate size (app size + 20MB padding)
APP_SIZE=$(du -sm "${APP_NAME}.app" | cut -f1)
DMG_SIZE=$(( APP_SIZE + 20 ))

# Create writable DMG
hdiutil create \
    -size "${DMG_SIZE}m" \
    -fs HFS+ \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -format UDRW \
    -ov \
    "$DMG_TEMP" \
    -quiet

ok "Writable DMG created"

# ── Style the DMG ────────────────────────────────────────────
log "Styling DMG window..."

MOUNT_DIR="/Volumes/${VOLUME_NAME}"

# Mount
hdiutil attach "$DMG_TEMP" -mountpoint "$MOUNT_DIR" -quiet

# AppleScript to set Finder window appearance
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 800, 520}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set position of item "${APP_NAME}.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        set position of item "README.txt" of container window to {300, 350}
        close
        open
        update without registering applications
    end tell
end tell
APPLESCRIPT

# Give Finder time to write .DS_Store
sleep 2

# Hide README a bit (optional - keep it visible but small)
# SetFile -a V "$MOUNT_DIR/README.txt" 2>/dev/null || true

# Unmount
hdiutil detach "$MOUNT_DIR" -quiet
ok "DMG styled"

# ── Compress to final DMG ────────────────────────────────────
log "Compressing final DMG..."
hdiutil convert "$DMG_TEMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_FINAL" \
    -quiet

rm -f "$DMG_TEMP"
rm -rf "$STAGING_DIR"

FINAL_SIZE=$(du -h "$DMG_FINAL" | cut -f1 | xargs)
ok "Created ${DMG_FINAL} (${FINAL_SIZE})"

echo ""
echo -e "${GREEN}${BOLD}  ✓ DMG ready to share!${NC}"
echo ""
echo "  File: ${PROJECT_DIR}/${DMG_FINAL}"
echo "  Size: ${FINAL_SIZE}"
echo ""
echo "  Share via AirDrop, Slack, or any file sharing service."
echo "  Your team just needs to:"
echo "    1. Open the DMG"
echo "    2. Drag the app to Applications"
echo "    3. Launch from Spotlight or Launchpad"
echo ""
