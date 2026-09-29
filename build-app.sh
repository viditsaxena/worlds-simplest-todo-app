#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h}"
APP_NAME="World's Simplest To-Do"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
TARGET_ARCH="$(uname -m)"
TARGET_MACOS="$(sw_vers -productVersion | cut -d. -f1)"

cd "$ROOT_DIR"
mkdir -p ".build/release"
mkdir -p ".build/cache/clang"

CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/cache/clang" \
swiftc \
    -O \
    -parse-as-library \
    -target "$TARGET_ARCH-apple-macosx$TARGET_MACOS.0" \
    -sdk "$(xcrun --show-sdk-path)" \
    -o ".build/release/WorldsSimplestTodo" \
    Sources/WorldsSimplestTodo/*.swift \
    -framework AppKit \
    -framework Carbon \
    -framework SwiftUI \
    -framework UserNotifications

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp ".build/release/WorldsSimplestTodo" "$APP_DIR/Contents/MacOS/WorldsSimplestTodo"
cp "App/Info.plist" "$APP_DIR/Contents/Info.plist"

codesign --force --deep --sign - "$APP_DIR"

print "Built $APP_DIR"
