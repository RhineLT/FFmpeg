#!/usr/bin/env bash
set -euo pipefail

# Prepare environment variables for iOS cross-compile on GitHub macOS runners

XCODE_PATH=$(xcode-select -p)
IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION=${IOS_MIN_VERSION:-12.0}

# Use repository-root/ios-build/out as prefix to keep artifacts contained
ROOT_DIR=$(pwd)
IOS_PREFIX="$ROOT_DIR/ios-build/out"
mkdir -p "$IOS_PREFIX"

{
  echo "XCODE_PATH=$XCODE_PATH"
  echo "IOS_SDK_PATH=$IOS_SDK_PATH"
  echo "IOS_MIN_VERSION=$IOS_MIN_VERSION"
  echo "IOS_PREFIX=$IOS_PREFIX"
} >> "$GITHUB_ENV"

cat <<EOF
[setup-env]
XCODE_PATH=$XCODE_PATH
IOS_SDK_PATH=$IOS_SDK_PATH
IOS_MIN_VERSION=$IOS_MIN_VERSION
IOS_PREFIX=$IOS_PREFIX
EOF
