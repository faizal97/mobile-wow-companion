#!/bin/bash
# Clears all app caches EXCEPT login token (bnet_access_token).
# Works for Chrome (web) localStorage and iOS/Android SharedPreferences.

set -e

APP_DIR="/Users/fayz/Code/Personal/mobile-wow-companion"
APP_ID="com.example.wow_companion"

echo "=== WoW Companion — Clear Cache (keep login) ==="

# ─── Web (Chrome) ────────────────────────────────────────────────────────
# SharedPreferences on web uses localStorage with "flutter." prefix
CHROME_PROFILE="$HOME/Library/Application Support/Google/Chrome/Default"
WEB_STORAGE=$(find "$CHROME_PROFILE/Local Storage/leveldb" -name "*.log" -o -name "*.ldb" 2>/dev/null | head -1)

if [ -n "$WEB_STORAGE" ]; then
  echo ""
  echo "⚠ Web (Chrome): localStorage can't be selectively cleared from shell."
  echo "  Open DevTools (F12) → Application → Local Storage → localhost:8080"
  echo "  Delete all keys EXCEPT 'flutter.bnet_access_token'"
  echo ""
  echo "  Or paste this in the Console:"
  echo '  Object.keys(localStorage).filter(k => k !== "flutter.bnet_access_token").forEach(k => localStorage.removeItem(k))'
fi

# ─── iOS Simulator ───────────────────────────────────────────────────────
IOS_PLIST=$(find ~/Library/Developer/CoreSimulator/Devices -path "*/data/Containers/Data/Application/*/Library/Preferences/*.plist" -name "*wow*" -o -name "*$APP_ID*" 2>/dev/null | head -1)

if [ -n "$IOS_PLIST" ]; then
  echo ""
  echo "iOS Simulator: clearing SharedPreferences (keeping login)..."
  # Read current token
  TOKEN=$(defaults read "${IOS_PLIST%.plist}" "flutter.bnet_access_token" 2>/dev/null || true)
  # Delete all flutter keys
  defaults delete "${IOS_PLIST%.plist}" 2>/dev/null || true
  # Restore token
  if [ -n "$TOKEN" ]; then
    defaults write "${IOS_PLIST%.plist}" "flutter.bnet_access_token" -string "$TOKEN"
    echo "  ✓ Cleared all cache, preserved login token"
  else
    echo "  ✓ Cleared all cache (no login token found)"
  fi
fi

# ─── Android Emulator ────────────────────────────────────────────────────
if command -v adb &>/dev/null && adb devices | grep -q "device$"; then
  ANDROID_PREFS="/data/data/$APP_ID/shared_prefs/FlutterSharedPreferences.xml"
  if adb shell "test -f $ANDROID_PREFS" 2>/dev/null; then
    echo ""
    echo "Android: clearing SharedPreferences (keeping login)..."
    adb shell "run-as $APP_ID sh -c '
      TOKEN=\$(grep bnet_access_token shared_prefs/FlutterSharedPreferences.xml | sed \"s/.*value=\\\"//;s/\\\".*//' 2>/dev/null)
      rm -f shared_prefs/FlutterSharedPreferences.xml
      if [ -n \"\$TOKEN\" ]; then
        echo \"<?xml version=\\\"1.0\\\" encoding=\\\"utf-8\\\"?><map><string name=\\\"flutter.bnet_access_token\\\">\$TOKEN</string></map>\" > shared_prefs/FlutterSharedPreferences.xml
      fi
    '" 2>/dev/null && echo "  ✓ Cleared" || echo "  ✗ Failed (app not installed?)"
  fi
fi

# ─── Flutter build cache ─────────────────────────────────────────────────
echo ""
echo "Quick restart tip: press 'R' in the flutter run terminal for hot restart"
echo ""
echo "Cache keys that will be cleared on next app launch:"
echo "  - mount_journal_data (SimpleArmory mounts)"
echo "  - mount_wago_data_v4 (Wago: acquisition, lore, currencies, journal)"
echo "  - mount_displays_data (creature display IDs from MountXDisplay)"
echo "  - mount_collection_data (collected status)"
echo "  - wow_char_* (character cache)"
echo "  - wow_equip_* (equipment cache)"
echo "  - wow_mplus_* (M+ cache)"
echo "  - wow_raid_* (raid cache)"
echo "  - wow_ach_* (achievement cache)"
echo ""
echo "Preserved:"
echo "  - bnet_access_token (login)"
echo ""
echo "Done!"
