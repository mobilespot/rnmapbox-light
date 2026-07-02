#!/usr/bin/env bash
set -euo pipefail

LOGDIR="logs"
mkdir -p "$LOGDIR"
TS=$(date +%Y%m%d-%H%M%S)
LOGFILE="$LOGDIR/no-geoloc-finalize-$TS.log"

exec > >(tee -a "$LOGFILE") 2>&1

echo "[INFO] no-geoloc finalize started at $(date)"
echo "[INFO] PWD=$(pwd)"

function run() {
  echo "\n[CMD] $*"
  "$@"
  local rc=$?
  echo "[RC] $rc"
  return $rc
}

CURR=$(git rev-parse --abbrev-ref HEAD || true)
echo "[INFO] current branch: $CURR"
if [ "$CURR" != "no-geoloc-upgrade" ]; then
  echo "[ERROR] Please checkout no-geoloc-upgrade before running this script. Aborting."
  echo "[DONE] log: $LOGFILE"
  exit 1
fi

echo "[STEP] Remove upstream example directory (Option A)"
run git rm -r -f --ignore-unmatch example || true

echo "[STEP] Keep our version for legacy Java API and stage it"
LEGACY_FILE="android/src/main/old-arch/com/facebook/react/viewmanagers/RNMBXCameraManagerDelegate.java"
if [ -f "$LEGACY_FILE" ]; then
  run git checkout --ours -- "$LEGACY_FILE" || true
  run git add "$LEGACY_FILE" || true
else
  echo "[WARN] $LEGACY_FILE not present"
fi

echo "[STEP] Stage all changes and commit merge result"
run git add -A || true
run git commit -m "chore: merge upstream into no-geoloc-upgrade — preserve no-geoloc (auto-finalize)" || true

echo "[STEP] Install deps and run codegen"
if command -v yarn >/dev/null 2>&1; then
  run yarn install || true
  run yarn generate || run yarn prepare || true
else
  echo "[WARN] yarn not found; skipping yarn steps"
fi

echo "[STEP] iOS pod install (if ios dir present)"
if [ -d ios ]; then
  run bash -c "cd ios && pod install --repo-update" || true
fi

echo "[STEP] Android assembleDebug (if android dir present)"
if [ -d android ]; then
  run bash -c "cd android && ./gradlew assembleDebug" || true
fi

echo "[STEP] Lint and tests"
run yarn lint || true
run yarn test || true

echo "[STEP] Scan for geolocation artifacts"
run grep -RIn --exclude-dir=node_modules "Location\|ACCESS_FINE_LOCATION\|requestPermission\|navigator.geolocation" . || true

echo "[DONE] no-geoloc finalize finished at $(date) — log: $LOGFILE"
