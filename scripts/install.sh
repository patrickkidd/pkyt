#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${DEVICE:-6318CDF1-BFF0-59D3-9637-2F4B4B15C2DC}"
xcodegen generate
xcodebuild build -project pkyt.xcodeproj -scheme pkyt -configuration Release \
    -destination "generic/platform=iOS" -derivedDataPath build/device \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration
APP=build/device/Build/Products/Release-iphoneos/pkyt.app
xcrun devicectl device install app --device "$DEVICE" "$APP"
xcrun devicectl device process launch --device "$DEVICE" com.patrickkidd.pkyt
