#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Habibi Float"
DIST_DIR="dist"
APP_PATH="${DIST_DIR}/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
STAGING_DIR="${DIST_DIR}/dmg-staging"

if [ ! -d "${APP_PATH}" ]; then
  ./scripts/build-app.sh
fi

rm -rf "${STAGING_DIR}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"

cp -R "${APP_PATH}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" >/dev/null

rm -rf "${STAGING_DIR}"

echo "Built ${DMG_PATH}"
