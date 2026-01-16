#!/usr/bin/env bash
set -euo pipefail
# Usage: expects environment variables:
# IOS_P12_BASE64, IOS_P12_PASSWORD, IOS_PROVISIONING_BASE64

mkdir -p "$HOME/certs"
echo "$IOS_P12_BASE64" | base64 --decode > "$HOME/certs/cert.p12"

# create and unlock a keychain for CI
KEYCHAIN_PATH="$HOME/Library/Keychains/build.keychain"
security create-keychain -p "" "$KEYCHAIN_PATH" || true
security import "$HOME/certs/cert.p12" -k "$KEYCHAIN_PATH" -P "$IOS_P12_PASSWORD" -T /usr/bin/codesign || true
security list-keychains -s "$KEYCHAIN_PATH" || true
security default-keychain -s "$KEYCHAIN_PATH" || true
security unlock-keychain -p "" "$KEYCHAIN_PATH" || true
security set-key-partition-list -S apple-tool:,apple: -s -k "" "$KEYCHAIN_PATH" || true

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
echo "$IOS_PROVISIONING_BASE64" | base64 --decode > "$HOME/Library/MobileDevice/Provisioning Profiles/app.mobileprovision"

echo "Certificates and provisioning profile installed." 
