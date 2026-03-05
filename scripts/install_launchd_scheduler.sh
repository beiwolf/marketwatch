#!/bin/zsh
set -euo pipefail

BASE="/Users/bot1/Desktop/marketwatch"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST="$PLIST_DIR/com.beiwolf.marketwatch.scheduler.plist"
mkdir -p "$PLIST_DIR"

cat > "$PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.beiwolf.marketwatch.scheduler</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/bot1/Desktop/marketwatch/automation.sh</string>
  </array>
  <key>WorkingDirectory</key><string>/Users/bot1/Desktop/marketwatch</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/Users/bot1/Desktop/marketwatch/automation.log</string>
  <key>StandardErrorPath</key><string>/Users/bot1/Desktop/marketwatch/automation.err.log</string>
</dict>
</plist>
PLIST

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

printf "Installed and loaded %s\n" "com.beiwolf.marketwatch.scheduler"
launchctl list | grep com.beiwolf.marketwatch.scheduler || true
