#!/usr/bin/env bash
# Deploy Puzzle Vault (Top Games) to the Play Store and/or App Store Connect.
#
# Usage:
#   ./deploy.sh                            # prompt for version, deploy Android + iOS
#   ./deploy.sh android                    # Android only
#   ./deploy.sh ios                        # iOS only
#   ./deploy.sh android --track=internal   # push to an Android testing track instead of production
#   ./deploy.sh android --validate-only    # dry-run the Play upload (auth + packaging checks, nothing published)
#   ./deploy.sh --no-bump                  # skip the version prompt, deploy the current build as-is
#   ./deploy.sh --yes                      # skip the version prompt, auto-confirm the bump
#
# What it does:
#   1. Shows the current version and asks you to approve bumping the build number, retry the
#      current build as-is (no bump), or cancel. --no-bump / --yes skip the prompt.
#   2. Runs `flutter analyze` and `flutter test` as a gate — deploy stops if either fails.
#   3. Android: `flutter build appbundle` + uploads the .aab to Google Play via fastlane/supply
#      (service account: android/play-deploy-key.json). Defaults to the production track,
#      submitted for review immediately (this is a real publish — Google still runs its own
#      review before it goes live). Not a draft: use --validate-only to test without publishing.
#   4. iOS: `flutter build ipa` exports locally, then fastlane (App Store Connect API key)
#      uploads the .ipa, sets release notes, and submits it for App Store review. This is
#      "submit for review" only — automatic_release is off, so it will NOT go live on its own
#      once Apple approves it; that final release is still a deliberate manual step in App
#      Store Connect.
#   5. If the version changed, commits and pushes that change to git.
#
# NOTE: android/play-deploy-key.json here reuses the same Play Console service account as
# csquest. If it hasn't been granted access to this app (com.katariya.topgames) in Play
# Console yet, `--validate-only` will fail with a clear permission error — grant it there first.
#
# The script only prints "Deploy complete" after every requested platform's upload has
# actually finished — nothing is backgrounded, so a finished run means a finished deploy.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

log() {
  echo "[$(date '+%H:%M:%S')] $*"
}

record_deploy() {
  local target="$1" version="$2"
  local history_file="$ROOT/.deploy-history.json"
  local commit entry
  commit="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  entry="$(jq -n --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg target "$target" \
    --arg version "$version" --arg commit "$commit" \
    '{timestamp:$ts, target:$target, version:$version, commit:$commit}')"
  if [[ -f "$history_file" ]]; then
    jq --argjson entry "$entry" '. + [$entry]' "$history_file" > "$history_file.tmp" && mv "$history_file.tmp" "$history_file"
  else
    jq -n --argjson entry "$entry" '[$entry]' > "$history_file"
  fi
}

TARGET="both"
PROMPT=1
AUTO_YES=0
BUMP_TYPE="build"
FASTLANE_ARGS=()

# App Store Connect API key ("deploy-automation", App Manager role) — shared across all four
# apps on this account. Used for an explicit `altool --upload-app` upload after the local
# export, instead of relying on xcodebuild's `destination: upload`, which has been observed to
# silently skip the actual upload (falls back to printing manual-upload instructions) without
# failing the build. The private key itself lives at
# ~/.appstoreconnect/private_keys/AuthKey_<key id>.p8 (altool finds it there automatically).
APP_STORE_CONNECT_KEY_ID="9PZA66NX9Q"
APP_STORE_CONNECT_ISSUER_ID="6dc856b0-c8b9-4763-9f74-65180d9e678b"
BRANCH="$(git branch --show-current)"

for arg in "$@"; do
  case "$arg" in
    android|ios|both) TARGET="$arg" ;;
    --no-bump) PROMPT=0 ;;
    --yes|-y) AUTO_YES=1 ;;
    --bump=*) BUMP_TYPE="${arg#--bump=}" ;;
    --track=*) FASTLANE_ARGS+=("track:${arg#--track=}") ;;
    --validate-only) FASTLANE_ARGS+=("validate_only:true") ;;
    --release-status=*) FASTLANE_ARGS+=("release_status:${arg#--release-status=}") ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

case "$BUMP_TYPE" in
  major|minor|patch|build) ;;
  *)
    echo "Unknown --bump value: $BUMP_TYPE (expected major, minor, patch, or build)" >&2
    exit 1
    ;;
esac

log "Deploy target: $TARGET"

current_version="$(grep '^version:' pubspec.yaml | sed 's/version: //')"
version_name="${current_version%+*}"
build_number="${current_version##*+}"
next_build=$((build_number + 1))

IFS='.' read -r ver_major ver_minor ver_patch <<< "$version_name"
build_bump="${version_name}+${next_build}"
patch_bump="${ver_major}.${ver_minor}.$((ver_patch + 1))+${next_build}"
minor_bump="${ver_major}.$((ver_minor + 1)).0+${next_build}"
major_bump="$((ver_major + 1)).0.0+${next_build}"

case "$BUMP_TYPE" in
  major) bumped_version="$major_bump" ;;
  minor) bumped_version="$minor_bump" ;;
  patch) bumped_version="$patch_bump" ;;
  build) bumped_version="$build_bump" ;;
esac

new_version="$current_version"

if [[ "$PROMPT" == "0" ]]; then
  log "Deploying current version as-is: $current_version (--no-bump)"
elif [[ "$AUTO_YES" == "1" ]]; then
  new_version="$bumped_version"
  log "Bumping $BUMP_TYPE version: $current_version -> $new_version (--yes)"
else
  echo ""
  echo "Current version: $current_version"
  echo "  [Enter]  Bump build number -> $build_bump and deploy"
  echo "  p        Bump patch       -> $patch_bump and deploy"
  echo "  m        Bump minor       -> $minor_bump and deploy"
  echo "  M        Bump major       -> $major_bump and deploy"
  echo "  r        Retry $current_version as-is (no bump)"
  echo "  c        Cancel"
  read -r -p "> " choice
  case "$choice" in
    ""|y|Y|b|B)
      new_version="$build_bump"
      log "Bumping build number: $current_version -> $new_version"
      ;;
    p)
      new_version="$patch_bump"
      log "Bumping patch version: $current_version -> $new_version"
      ;;
    m)
      new_version="$minor_bump"
      log "Bumping minor version: $current_version -> $new_version"
      ;;
    M)
      new_version="$major_bump"
      log "Bumping major version: $current_version -> $new_version"
      ;;
    r|R)
      log "Retrying current version as-is: $current_version"
      ;;
    *)
      log "Cancelled."
      exit 1
      ;;
  esac
fi

if [[ "$new_version" != "$current_version" ]]; then
  sed -i '' "s/^version: .*/version: ${new_version}/" pubspec.yaml
fi

log "Running flutter analyze..."
analyze_log="$(mktemp)"
set +e
flutter analyze 2>&1 | tee "$analyze_log"
analyze_status="${PIPESTATUS[0]}"
set -e
if [[ "$analyze_status" != "0" ]]; then
  if grep -qE '^\s*error •' "$analyze_log"; then
    echo "flutter analyze found real errors — deploy stopped." >&2
    rm -f "$analyze_log"
    exit 1
  else
    log "flutter analyze found only info/warning-level issues; continuing."
  fi
fi
rm -f "$analyze_log"

log "Running flutter test..."
flutter test

deploy_android() {
  if [[ ! -f "android/play-deploy-key.json" ]]; then
    echo "Missing android/play-deploy-key.json — Android deploy skipped." >&2
    exit 1
  fi
  log "[Android] Building App Bundle and uploading to Google Play..."
  fastlane android deploy "${FASTLANE_ARGS[@]+"${FASTLANE_ARGS[@]}"}"
  log "[Android] Upload complete."
  record_deploy "android" "$new_version"
}

deploy_ios() {
  if [[ ! -f "ios/ExportOptions/ExportOptions.plist" ]]; then
    echo "Missing ios/ExportOptions/ExportOptions.plist — iOS deploy skipped." >&2
    exit 1
  fi
  log "[iOS] Building and exporting archive..."
  local log_file
  log_file="$(mktemp)"
  set +e
  flutter build ipa --export-options-plist=ios/ExportOptions/ExportOptions.plist 2>&1 | tee "$log_file"
  local build_status="${PIPESTATUS[0]}"
  set -e
  if [[ "$build_status" != "0" ]]; then
    if grep -q "Xcode archive done" "$log_file" && grep -q "Flutter failed to list directory" "$log_file"; then
      log "[iOS] Archive/export succeeded; ignoring Flutter's known harmless local .ipa directory-listing error."
    else
      echo "[iOS] Build failed — see log above." >&2
      rm -f "$log_file"
      exit 1
    fi
  fi
  rm -f "$log_file"

  local ipa_path
  ipa_path="$(find build/ios/ipa -maxdepth 1 -iname '*.ipa' | head -1)"
  if [[ -z "$ipa_path" ]]; then
    echo "[iOS] No .ipa found in build/ios/ipa after build — nothing to upload." >&2
    exit 1
  fi

  log "[iOS] Uploading $(basename "$ipa_path") and submitting for App Store review..."
  local new_version_name="${new_version%+*}"
  APP_STORE_CONNECT_KEY_ID="$APP_STORE_CONNECT_KEY_ID" \
  APP_STORE_CONNECT_ISSUER_ID="$APP_STORE_CONNECT_ISSUER_ID" \
    fastlane ios deploy "ipa_path:$ipa_path" "app_version:$new_version_name"
  log "[iOS] Submitted for App Store review."
  record_deploy "ios" "$new_version"
}

case "$TARGET" in
  android) deploy_android ;;
  ios) deploy_ios ;;
  both) deploy_android; deploy_ios ;;
esac

if [[ "$new_version" != "$current_version" ]]; then
  log "Committing version bump..."
  git add pubspec.yaml
  git commit -m "Bump build number to ${new_version}"
  git push origin "$BRANCH"
fi

log "Deploy complete: $TARGET @ $new_version"
