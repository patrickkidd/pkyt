#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
xcodegen generate
xcodebuild build -project pkyt.xcodeproj -scheme pkyt -configuration Release \
    -destination "generic/platform=iOS" -derivedDataPath build/device \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration
APP=build/device/Build/Products/Release-iphoneos/pkyt.app
xcrun devicectl device install app --device "$PKYT_DEVICE" "$APP"
xcrun devicectl device process launch --device "$PKYT_DEVICE" com.patrickkidd.pkyt
