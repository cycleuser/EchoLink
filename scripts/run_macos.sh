#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"
export JAVA_HOME="$HOME/jdk/zulu17.54.21-ca-jdk17.0.13-macosx_aarch64/zulu-17.jdk/Contents/Home"
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

echo "========================================"
echo "  EchoLink - macOS Build & Run"
echo "========================================"
echo ""

cd "$PROJECT_DIR"

echo "[1/3] Getting dependencies..."
flutter pub get

echo ""
echo "[2/3] Building macOS app..."
flutter build macos --debug

echo ""
echo "[3/3] Running macOS app..."
flutter run -d macos

echo ""
echo "Done!"