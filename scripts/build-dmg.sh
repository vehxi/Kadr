#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Kadr.xcodeproj"
SCHEME="Kadr"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build/release}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
STAGING_DIR="$BUILD_ROOT/dmg-root"
APP_PATH="$DERIVED_DATA/Build/Products/Release/Kadr.app"
VERSION="${VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"

if [[ -z "$VERSION" ]]; then
    VERSION="$(
        xcodebuild \
            -project "$PROJECT_PATH" \
            -scheme "$SCHEME" \
            -showBuildSettings |
        awk '/ MARKETING_VERSION = / { print $3; exit }'
    )"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
    IFS=. read -r major minor patch <<< "$VERSION"
    if [[ ! "$major" =~ ^[0-9]+$ || ! "$minor" =~ ^[0-9]+$ || ! "$patch" =~ ^[0-9]+$ ]]; then
        echo "VERSION must use numeric major.minor.patch format." >&2
        exit 1
    fi
    BUILD_NUMBER=$((major * 1000000 + minor * 1000 + patch))
fi

DMG_PATH="$DIST_DIR/Kadr-$VERSION.dmg"

mkdir -p "$BUILD_ROOT" "$DIST_DIR"
rm -rf "$DERIVED_DATA" "$STAGING_DIR"

xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    clean build

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/Kadr.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "Kadr" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

hdiutil verify "$DMG_PATH"
shasum -a 256 "$DMG_PATH"
echo "Created $DMG_PATH"
