#!/bin/bash
set -e

APP_NAME="Dynamic Horizon Sync"
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}  Uninstall ${APP_NAME}${NC}"
echo ""

# Kill running instances
if pgrep -f "team-sync-web" &>/dev/null || pgrep -f "TeamSync" &>/dev/null; then
    echo "  Stopping running instances..."
    pkill -f "team-sync-web" 2>/dev/null || true
    pkill -f "TeamSync" 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}  ✓${NC} Processes stopped"
fi

# Remove app
if [ -d "/Applications/${APP_NAME}.app" ]; then
    rm -rf "/Applications/${APP_NAME}.app"
    echo -e "${GREEN}  ✓${NC} Removed /Applications/${APP_NAME}.app"
else
    echo "  /Applications/${APP_NAME}.app not found (skipped)"
fi

# Ask about data
if [ -d "$HOME/.dh-sync" ]; then
    read -p "  Delete config & data (~/.dh-sync)? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/.dh-sync"
        echo -e "${GREEN}  ✓${NC} Removed ~/.dh-sync"
    else
        echo "  Kept ~/.dh-sync"
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}  ✓ Uninstalled.${NC}"
echo ""
