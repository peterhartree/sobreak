#!/bin/bash
set -euo pipefail

# Deploy So Break: build, tag, push to GitHub, create release, update homebrew tap.
#
# Usage:
#   ./deploy.sh <version>    e.g. ./deploy.sh 1.1.0
#
# What it does:
#   1. Builds the release app bundle
#   2. Creates a zip for the GitHub release
#   3. Pushes to GitHub and creates a tagged release with the zip
#   4. Computes SHA256 and updates the homebrew tap cask
#   5. Pushes the tap update

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SoBreak"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
TAP_REPO="peterhartree/homebrew-sobreak"

# ---- Parse version ----

if [ $# -lt 1 ]; then
    echo "Usage: $0 <version>  (e.g. 1.1.0)" >&2
    exit 1
fi

VERSION="$1"
TAG="v$VERSION"
ZIP_NAME="$APP_NAME-$VERSION.zip"
ZIP_PATH="$BUILD_DIR/$ZIP_NAME"

echo "=== Deploying $APP_NAME $VERSION ==="

# ---- Check clean working tree ----

if [ -n "$(git -C "$SCRIPT_DIR" status --porcelain)" ]; then
    echo "Error: working tree is not clean. Commit or stash changes first." >&2
    exit 1
fi

# ---- Check tag doesn't already exist ----

if git -C "$SCRIPT_DIR" rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Error: tag $TAG already exists." >&2
    exit 1
fi

# ---- Build ----

echo ""
echo "1. Building release..."
"$SCRIPT_DIR/build.sh"

# ---- Create zip ----

echo ""
echo "2. Creating $ZIP_NAME..."
cd "$BUILD_DIR"
rm -f "$ZIP_NAME"
zip -r -q "$ZIP_NAME" "$APP_NAME.app"
cd "$SCRIPT_DIR"

SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
echo "   SHA256: $SHA256"

# ---- Push to GitHub ----

echo ""
echo "3. Pushing to GitHub..."
git -C "$SCRIPT_DIR" push origin main

# ---- Create GitHub release ----

echo ""
echo "4. Creating GitHub release $TAG..."
gh release create "$TAG" "$ZIP_PATH" \
    --repo peterhartree/sobreak \
    --title "$APP_NAME $VERSION" \
    --notes "Release $VERSION"

# ---- Update homebrew tap ----

echo ""
echo "5. Updating homebrew tap..."

TAP_DIR=$(mktemp -d)
gh repo clone "$TAP_REPO" "$TAP_DIR" -- -q 2>/dev/null

# Remove legacy cask from pre-rename (ignored if already gone)
rm -f "$TAP_DIR/Casks/takebreak.rb"

CASK_FILE="$TAP_DIR/Casks/sobreak.rb"

cat > "$CASK_FILE" << CASK
cask "sobreak" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/peterhartree/sobreak/releases/download/v#{version}/SoBreak-#{version}.zip"
  name "So Break"
  desc "Menu bar break reminder app for macOS"
  homepage "https://github.com/peterhartree/sobreak"

  app "SoBreak.app"

  zap trash: [
    "~/Library/Preferences/is.pjh.so-break.plist",
  ]
end
CASK

cd "$TAP_DIR"
git add -A Casks/
git commit -m "Update So Break to $VERSION"
git push origin main
cd "$SCRIPT_DIR"

rm -rf "$TAP_DIR"

echo ""
echo "=== Done! ==="
echo "  GitHub release: https://github.com/peterhartree/sobreak/releases/tag/$TAG"
echo "  Homebrew:       brew upgrade --cask sobreak"
