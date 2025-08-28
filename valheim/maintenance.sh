#!/bin/bash
# Valheim Server Maintenance Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/valheim-server.conf"

# Load configuration
source "$CONFIG_FILE"

echo "=== Valheim Server Maintenance ==="
echo "Date: $(date)"
echo ""

# Check disk space
echo "📊 Disk Space:"
df -h / | tail -1 | awk '{print "  Used: " $3 "/" $2 " (" $5 ") - Available: " $4}'
echo ""

# Clean up old logs
echo "🧹 Cleaning old logs..."
find /tmp -name "*valheim*log*" -mtime +7 -delete 2>/dev/null || true
echo "  Old log files cleaned"

# Clean up Steam cache
echo "🧹 Cleaning Steam cache..."  
rm -rf "$HOME/Steam/logs/*" 2>/dev/null || true
rm -rf "$HOME/Steam/crashhandler.so.*" 2>/dev/null || true
echo "  Steam cache cleaned"

# Check for server updates (don't auto-install)
echo "🔄 Checking for server updates..."
cd "$STEAMCMD_DIR"
./steamcmd.sh +login anonymous +app_info_update 1 +app_info_print 896660 +quit | grep -A5 "buildid" | tail -5

# Create automatic backup
echo "💾 Creating automatic backup..."
"$SCRIPT_DIR/valheim-server.sh" backup

# Show current server status
echo ""
echo "📊 Current Server Status:"
"$SCRIPT_DIR/valheim-server.sh" status

echo ""
echo "✅ Maintenance completed at $(date)"
