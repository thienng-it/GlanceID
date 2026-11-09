#!/usr/bin/env bash
set -euo pipefail

# GlanceID - Local macOS App Builder & Ad-Hoc Code Signer
# Works 100% without an Apple Developer Account.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="GlanceID"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "================================================="
echo " Building ${APP_NAME} for macOS (No Dev Account)"
echo "================================================="

# 1. Compile release binary using Swift Package Manager
echo "[1/6] Compiling Swift binary..."
cd "${PROJECT_DIR}"
swift build -c release

BIN_PATH="${PROJECT_DIR}/.build/release/${APP_NAME}"
if [ ! -f "${BIN_PATH}" ]; then
    echo "Error: Binary not found at ${BIN_PATH}"
    exit 1
fi

# 2. Prepare .app bundle directory structure
echo "[2/6] Creating application bundle structure..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 3. Copy executable and metadata
echo "[3/6] Packaging binary and Info.plist..."
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod 755 "${MACOS_DIR}/${APP_NAME}"

cp "${PROJECT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
if [ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# 4. Ad-hoc Code Signing
# Using '-' as the identity signs the app locally (Ad-Hoc), granting local TCC camera permissions
echo "[4/6] Ad-hoc code signing bundle with camera entitlements..."
ENTITLEMENTS="${PROJECT_DIR}/Resources/GlanceID.entitlements"

codesign --force --deep --sign - \
    --entitlements "${ENTITLEMENTS}" \
    "${APP_BUNDLE}"

# 5. Clear quarantine attributes to prevent Gatekeeper blockage
echo "[5/6] Removing quarantine flags..."
xattr -cr "${APP_BUNDLE}"

# Verify code sign
echo "Verifying code signature:"
codesign --verify --deep --strict --verbose=1 "${APP_BUNDLE}"

# 6. Create proper macOS distribution packages (.dmg and .zip via ditto)
echo "[6/6] Packaging distribution artifacts (.dmg and .zip)..."
# ditto preserves resource forks, execution permissions (+x), and code signatures
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${BUILD_DIR}/${APP_NAME}.zip"

# Create Apple Disk Image (.dmg)
hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_BUNDLE}" -ov -format UDZO "${BUILD_DIR}/${APP_NAME}.dmg"

echo ""
echo "✅ Build & Packaging Successful!"
echo "App Bundle: ${APP_BUNDLE}"
echo "Zip Archive: ${BUILD_DIR}/${APP_NAME}.zip"
echo "Disk Image: ${BUILD_DIR}/${APP_NAME}.dmg"
