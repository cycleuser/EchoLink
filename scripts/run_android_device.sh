#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"
export JAVA_HOME="$HOME/jdk/zulu17.54.21-ca-jdk17.0.13-macosx_aarch64/zulu-17.jdk/Contents/Home"
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

DEVICE_ID="${1:-}"

echo "========================================"
echo "  EchoLink - Android Device Build & Run"
echo "========================================"
echo ""

cd "$PROJECT_DIR"

echo "[1/4] Getting dependencies..."
flutter pub get

echo ""
echo "[2/4] Checking for connected Android devices..."
DEVICES=$(flutter devices 2>/dev/null | grep -i "android" | grep -v "emulator" | awk '{print $3}')

if [ -z "$DEVICES" ]; then
    echo "ERROR: No Android device connected"
    echo "Please connect your Android device and enable USB debugging"
    exit 1
fi

if [ -z "$DEVICE_ID" ]; then
    echo "Available devices:"
    flutter devices 2>/dev/null | grep -i "android" | grep -v "emulator"
    echo ""
    echo "Usage: $0 <device_id>"
    exit 1
fi

echo "Using device: $DEVICE_ID"

echo ""
echo "[3/4] Building Android APK..."
flutter build apk --release

echo ""
echo "[4/4] Installing on device..."
adb -s "$DEVICE_ID" install -r build/app/outputs/flutter-apk/app-release.apk

echo ""
echo "Launching app..."
adb -s "$DEVICE_ID" shell am start -n com.example.echolink/.MainActivity

echo ""
echo "Done! App installed and launched on device."