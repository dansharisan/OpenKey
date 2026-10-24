#!/bin/bash
# Build OpenKey for macOS from the command line, signed with your own certificate.
#
# Usage:
#   OPENKEY_TEAM=<your team id> scripts/build-macos.sh [Release|Debug]
#
# Find your team id in the OU field of your signing certificate:
#   security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
#
# The app is written to build/DerivedData/Build/Products/<config>/OpenKey.app

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-Release}"
TEAM="${OPENKEY_TEAM:?Set OPENKEY_TEAM to your Apple Developer team id}"

xcodebuild \
    -project "$ROOT/Sources/OpenKey/macOS/OpenKey.xcodeproj" \
    -scheme OpenKey \
    -configuration "$CONFIG" \
    -derivedDataPath "$ROOT/build/DerivedData" \
    DEVELOPMENT_TEAM="$TEAM" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Apple Development" \
    PROVISIONING_PROFILE_SPECIFIER= \
    build

echo "Built: $ROOT/build/DerivedData/Build/Products/$CONFIG/OpenKey.app"
