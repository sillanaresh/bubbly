#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Bubbly"
EXECUTABLE_NAME="HabibiFloat"
BUNDLE_ID="com.habibi.float"
DIST_DIR="dist"
APP_PATH="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_PATH="${APP_PATH}/Contents"
MACOS_PATH="${CONTENTS_PATH}/MacOS"
RESOURCES_PATH="${CONTENTS_PATH}/Resources"
ICON_PATH="${RESOURCES_PATH}/AppIcon.icns"
CHAT_BACKEND_URL="${HABIBI_CHAT_BACKEND_URL:-https://habibi-float-api.habibi-float.workers.dev/v1/chat}"

swift build -c release

rm -rf "${APP_PATH}"
mkdir -p "${MACOS_PATH}" "${RESOURCES_PATH}"

cp ".build/release/${EXECUTABLE_NAME}" "${MACOS_PATH}/${APP_NAME}"
swift scripts/generate-icon.swift "${ICON_PATH}"

cat > "${CONTENTS_PATH}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if [ -n "${CHAT_BACKEND_URL}" ]; then
  /usr/libexec/PlistBuddy -c "Add :HabibiChatBackendURL string ${CHAT_BACKEND_URL}" "${CONTENTS_PATH}/Info.plist"
fi

chmod +x "${MACOS_PATH}/${APP_NAME}"
codesign --force --sign - "${APP_PATH}" >/dev/null

echo "Built ${APP_PATH}"
echo "Run with: open \"${APP_PATH}\""
