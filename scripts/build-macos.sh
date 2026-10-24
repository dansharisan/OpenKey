#!/bin/bash
# Build OpenKey for macOS from the command line, signed with your own certificate.
#
# Usage:
#   OPENKEY_TEAM=<your team id> scripts/build-macos.sh [Release|Debug] [clean]
#
# Find your team id in the OU field of your signing certificate:
#   security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
#
# Without OPENKEY_TEAM the app is built unsigned (for CI); macOS won't keep its
# Accessibility permission, so sign builds you use.
#
# The app is written to build/DerivedData.noindex/Build/Products/<config>/OpenKey.app
# (".noindex" keeps Spotlight from listing this copy next to the installed app)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-Release}"
ACTION="build"
if [ "${2:-}" = "clean" ]; then
    ACTION="clean build"
fi

if [ -n "${OPENKEY_TEAM:-}" ]; then
    SIGNING=(DEVELOPMENT_TEAM="$OPENKEY_TEAM" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Development" PROVISIONING_PROFILE_SPECIFIER=)
else
    echo "OPENKEY_TEAM is not set: building unsigned"
    SIGNING=(CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=)
fi

xcodebuild \
    -project "$ROOT/Sources/OpenKey/macOS/OpenKey.xcodeproj" \
    -scheme OpenKey \
    -configuration "$CONFIG" \
    -derivedDataPath "$ROOT/build/DerivedData.noindex" \
    "${SIGNING[@]}" \
    $ACTION

echo "Built: $ROOT/build/DerivedData.noindex/Build/Products/$CONFIG/OpenKey.app"
