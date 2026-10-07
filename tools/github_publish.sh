#!/usr/bin/env bash
# Builds the release APK for the version currently set in pubspec.yaml,
# writes a matching manifest.json, and publishes both as a GitHub Release.
#
# Signed with whatever signingConfig the release buildType uses in
# apps/health_campaign_field_worker_app/android/app/build.gradle, built with
# --release so it's optimized/minified the same as a real shipped build.
#
# This is a deliberate, explicit action — it is never run automatically as
# part of a routine build. Requires tools/secrets.env (gitignored) containing
# a GITHUB_TOKEN=... line.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../apps/health_campaign_field_worker_app"

# The repo pins Flutter 3.22.2 (.fvmrc); the system flutter is a newer SDK.
FLUTTER="${FLUTTER:-$HOME/fvm/versions/3.22.2/bin/flutter}"

if [[ ! -f "$SCRIPT_DIR/secrets.env" ]]; then
  echo "Missing tools/secrets.env — create it with a GITHUB_TOKEN=... line." >&2
  exit 1
fi
set -a
source "$SCRIPT_DIR/secrets.env"
set +a
: "${GITHUB_TOKEN:?GITHUB_TOKEN not set in tools/secrets.env}"

OWNER_REPO="egov-skb/hcm-app-installer-demo"

VERSION_LINE=$(grep -m1 '^version:' pubspec.yaml || true)
VERSION_RE='^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)[[:space:]]*$'
if [[ ! "$VERSION_LINE" =~ $VERSION_RE ]]; then
  echo "Could not parse version+build from: $VERSION_LINE" >&2
  exit 1
fi
VERSION="${BASH_REMATCH[1]}"
VERSION_CODE="${BASH_REMATCH[2]}"

TAG="v$VERSION"
ASSET_NAME="app-v$VERSION-release.apk"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

echo "==> Building $ASSET_NAME (versionCode $VERSION_CODE)"
"$FLUTTER" build apk --release

SHA256=$(sha256sum "$APK_PATH" | cut -d' ' -f1)
SIZE=$(stat -c%s "$APK_PATH" 2>/dev/null || stat -f%z "$APK_PATH")

MANIFEST_PATH="$(mktemp -d)/manifest.json"
cat > "$MANIFEST_PATH" <<EOF
{
  "version": "$VERSION",
  "versionCode": $VERSION_CODE,
  "downloadUrl": "https://github.com/$OWNER_REPO/releases/latest/download/$ASSET_NAME",
  "sha256": "$SHA256",
  "size": $SIZE,
  "releaseNotes": "- In-app updates: download and install new versions from the home screen\n- The update card now appears only when a new version is available\n- Added Check for updates to the side menu\n- Update checks run automatically during background sync\n- Long release notes can be expanded with Show more",
  "mandatory": false
}
EOF

# GitHub's /latest/ resolves by publish date, not by versionCode — publishing
# a versionCode that isn't strictly newer than what's already live would
# otherwise make /latest/download/manifest.json start serving a downgrade.
# Detect that case up front and mark this release a prerelease instead, so
# GitHub excludes it from /latest/ resolution and the real latest release
# keeps serving.
CURRENT_LATEST_VERSION_CODE=$(curl -sL "https://github.com/$OWNER_REPO/releases/latest/download/manifest.json" \
  | grep -oE '"versionCode"[[:space:]]*:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' || true)

IS_PRERELEASE=false
if [[ -n "$CURRENT_LATEST_VERSION_CODE" && "$VERSION_CODE" -le "$CURRENT_LATEST_VERSION_CODE" ]]; then
  IS_PRERELEASE=true
  echo "==> versionCode $VERSION_CODE is not newer than the current latest ($CURRENT_LATEST_VERSION_CODE)"
  echo "    Publishing as a prerelease so /latest/ keeps pointing at the newer release."
fi

echo "==> Creating release $TAG (prerelease: $IS_PRERELEASE)"
RELEASE_JSON=$(curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "User-Agent: digit-installer-showcase-publish" \
  "https://api.github.com/repos/$OWNER_REPO/releases" \
  -d "{\"tag_name\":\"$TAG\",\"name\":\"$TAG\",\"body\":\"HCM Installer showcase $VERSION (versionCode $VERSION_CODE)\",\"draft\":false,\"prerelease\":$IS_PRERELEASE}")

RELEASE_ID=$(echo "$RELEASE_JSON" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
if [[ -z "$RELEASE_ID" ]]; then
  echo "Failed to create release. Response:" >&2
  echo "$RELEASE_JSON" >&2
  exit 1
fi

upload_asset() {
  local file="$1" name="$2" content_type="$3"
  echo "==> Uploading $name"
  curl -s -o /dev/null -w "    HTTP %{http_code}\n" -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "User-Agent: digit-installer-showcase-publish" \
    -H "Content-Type: $content_type" \
    --data-binary @"$file" \
    "https://uploads.github.com/repos/$OWNER_REPO/releases/$RELEASE_ID/assets?name=$name"
}

upload_asset "$MANIFEST_PATH" "manifest.json" "application/json"
upload_asset "$APK_PATH" "$ASSET_NAME" "application/vnd.android.package-archive"

echo "==> Done: https://github.com/$OWNER_REPO/releases/tag/$TAG"