#!/usr/bin/env bash
set -uo pipefail

LOGDIR="logs"
mkdir -p "$LOGDIR"
TS=$(date +%Y%m%d-%H%M%S)
LOGFILE="$LOGDIR/no-geoloc-upgrade-$TS.log"

exec > >(tee -a "$LOGFILE") 2>&1

echo "[INFO] no-geoloc auto-resolve started at $(date)"
echo "[INFO] PWD=$(pwd)"

function run() {
  echo "\n[CMD] $*"
  eval "$@"
  local rc=$?
  echo "[RC] $rc"
  return $rc
}

echo "[STEP] Ensure on branch no-geoloc-upgrade"
CURR=$(git rev-parse --abbrev-ref HEAD || true)
echo "[INFO] current branch: $CURR"
if [ "$CURR" != "no-geoloc-upgrade" ]; then
  echo "[ERROR] Please checkout no-geoloc-upgrade before running this script. Aborting."
  exit 1
fi

echo "[STEP] Stage deletions for location-related files (keeps them deleted)"
run git rm -f --ignore-unmatch \
  android/src/main/java/com/rnmapbox/rnmbx/components/location/RNMBXCustomLocationProvider.kt \
  android/src/main/java/com/rnmapbox/rnmbx/components/location/RNMBXCustomLocationProviderManager.kt \
  android/src/main/java/com/rnmapbox/rnmbx/components/location/RNMBXNativeUserLocationManager.kt \
  android/src/main/java/com/rnmapbox/rnmbx/modules/RNMBXLocationModule.kt \
  ios/RNMBX/RNMBXCustomLocationProvider.swift \
  ios/RNMBX/RNMBXCustomLocationProviderComponentView.h \
  ios/RNMBX/RNMBXCustomLocationProviderComponentView.mm \
  ios/RNMBX/RNMBXLocationModule.swift \
  ios/RNMBX/RNMBXNativeUserLocationComponentView.h \
  ios/RNMBX/RNMBXNativeUserLocationComponentView.mm \
  src/components/UserLocation.tsx \
  src/modules/location/locationManager.ts \
  src/specs/RNMBXCustomLocationProviderNativeComponent.ts \
  src/specs/RNMBXNativeUserLocationNativeComponent.ts \
  src/components/CustomLocationProvider.tsx \
  src/Mapbox.native.ts || true

echo "[STEP] Optionally remove example dir if intentionally deleted in your branch"
if [ -d example ]; then
  echo "[WARN] example directory exists. Skipping automatic removal. To remove, run: git rm -r example"
fi

echo "[STEP] Prefer our versions for specific conflict files and stage them"
FILES_TO_KEEP_OURS=(
  "android/src/main/java/com/rnmapbox/rnmbx/RNMBXPackage.kt"
  "ios/RNMBX/RNMBXCamera.swift"
  "src/components/MapView.tsx"
  "package.json"
  "scripts/autogenHelpers/examplesJsonSchema.ts"
  "tsconfig.json"
  "yarn.lock"
)

for f in "${FILES_TO_KEEP_OURS[@]}"; do
  if [ -f "$f" ]; then
    echo "[ACTION] checkout --ours $f"
    run git checkout --ours -- "$f" || true
    run git add "$f" || true
  else
    echo "[SKIP] $f not present"
  fi
done

echo "[STEP] Show remaining conflicts"
run git diff --name-only --diff-filter=U || true

REMAINING=$(git diff --name-only --diff-filter=U || true)
if [ -z "$REMAINING" ]; then
  echo "[INFO] No remaining conflicts — committing merge"
  run git commit -m "chore: merge upstream into no-geoloc-upgrade — preserve no-geoloc" || true
else
  echo "[WARN] Conflicts remain; please resolve them manually. Remaining files:" 
  echo "$REMAINING"
  echo "[INFO] Log file: $LOGFILE"
  exit 0
fi

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

echo "[DONE] no-geoloc auto-resolve finished at $(date) — log: $LOGFILE"
