#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Kadr.xcodeproj"
SCHEME="Kadr"
REPOSITORY="${REPOSITORY:-vehxi/Kadr}"
KEYCHAIN_ACCOUNT="${SPARKLE_KEYCHAIN_ACCOUNT:-com.vehxi.Kadr}"
BRANCH="$(git -C "$ROOT_DIR" branch --show-current)"

if [[ "$BRANCH" != "main" ]]; then
    echo "Release must be published from the main branch." >&2
    exit 1
fi

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
    echo "Commit or stash all changes before publishing a release." >&2
    exit 1
fi

command -v gh >/dev/null || {
    echo "GitHub CLI (gh) is required." >&2
    exit 1
}

gh auth status >/dev/null
git -C "$ROOT_DIR" fetch origin main --tags --quiet

LOCAL_COMMIT="$(git -C "$ROOT_DIR" rev-parse HEAD)"
REMOTE_COMMIT="$(git -C "$ROOT_DIR" rev-parse origin/main)"

if [[ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]]; then
    echo "Local main must match origin/main before publishing." >&2
    exit 1
fi

VERSION="$(
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -showBuildSettings |
    awk '/ MARKETING_VERSION = / { print $3; exit }'
)"
TAG="v$VERSION"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "MARKETING_VERSION must use major.minor.patch format." >&2
    exit 1
fi

if git -C "$ROOT_DIR" rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Tag $TAG already exists. Increase MARKETING_VERSION first." >&2
    exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kadr-release.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

DIST_DIR="$WORK_DIR/dist"
mkdir -p "$DIST_DIR"

VERSION="$VERSION" \
DIST_DIR="$DIST_DIR" \
    "$ROOT_DIR/scripts/build-dmg.sh"

DMG_PATH="$DIST_DIR/Kadr-$VERSION.dmg"
RELEASE_NOTES="$DIST_DIR/Kadr-$VERSION.md"
PREVIOUS_TAG="$(
    git -C "$ROOT_DIR" describe \
        --tags \
        --abbrev=0 \
        2>/dev/null || true
)"

{
    echo "## Что изменилось"
    git -C "$ROOT_DIR" log \
        --no-merges \
        --reverse \
        --pretty="- %s" \
        "${PREVIOUS_TAG:+$PREVIOUS_TAG..}HEAD"

    if [[ -n "$PREVIOUS_TAG" ]]; then
        echo
        echo "**Полный список изменений**: https://github.com/$REPOSITORY/compare/$PREVIOUS_TAG...$TAG"
    fi
} > "$RELEASE_NOTES"

curl \
    --fail \
    --location \
    --silent \
    --show-error \
    "https://github.com/$REPOSITORY/releases/latest/download/appcast.xml" \
    --output "$DIST_DIR/appcast.xml" || rm -f "$DIST_DIR/appcast.xml"

SPARKLE_BIN="$(
    find "$ROOT_DIR/build/release/DerivedData/SourcePackages/artifacts" \
        -type d \
        -path '*/Sparkle/bin' \
        -print \
        -quit
)"

if [[ -z "$SPARKLE_BIN" || ! -x "$SPARKLE_BIN/generate_appcast" ]]; then
    echo "Sparkle release tools were not found after the build." >&2
    exit 1
fi

"$SPARKLE_BIN/generate_appcast" \
    --account "$KEYCHAIN_ACCOUNT" \
    --download-url-prefix "https://github.com/$REPOSITORY/releases/download/$TAG/" \
    --link "https://github.com/$REPOSITORY" \
    --embed-release-notes \
    "$DIST_DIR"

ASSETS=("$DMG_PATH" "$DIST_DIR/appcast.xml")
while IFS= read -r -d '' delta; do
    ASSETS+=("$delta")
done < <(find "$DIST_DIR" -maxdepth 1 -name '*.delta' -print0)

gh release create "$TAG" \
    "${ASSETS[@]}" \
    --repo "$REPOSITORY" \
    --target "$LOCAL_COMMIT" \
    --notes-file "$RELEASE_NOTES" \
    --title "Kadr $TAG" \
    --latest

echo "Published Kadr $TAG: https://github.com/$REPOSITORY/releases/tag/$TAG"
