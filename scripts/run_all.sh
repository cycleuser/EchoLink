#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"
export JAVA_HOME="$HOME/jdk/zulu17.54.21-ca-jdk17.0.13-macosx_aarch64/zulu-17.jdk/Contents/Home"
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

echo "========================================"
echo "  EchoLink - Run All Platforms"
echo "========================================"
echo ""

cd "$PROJECT_DIR"

pkill -f echolink 2>/dev/null || true
pkill -f Runner 2>/dev/null || true
pkill -f flutter 2>/dev/null || true
sleep 2

echo "[1/4] Getting dependencies..."
flutter pub get

echo ""
echo "[2/4] Starting macOS..."
flutter run -d macos &
MACOS_PID=$!
sleep 5

echo ""
echo "[3/4] Starting iOS Simulator..."
IOS_SIM_ID=$(flutter devices 2>/dev/null | grep -E "iPhone.*simulator" | head -1 | sed 's/.*• //' | sed 's/ •.*//' | tr -d ' ')
if [ -n "$IOS_SIM_ID" ]; then
    echo "iOS Simulator ID: $IOS_SIM_ID"
    flutter run -d "$IOS_SIM_ID" &
    IOS_PID=$!
    sleep 5
else
    echo "WARNING: No iOS Simulator found, skipping..."
fi

echo ""
echo "[4/4] Starting Android Emulator..."
ANDROID_DEVICE=$(flutter devices 2>/dev/null | grep -i "emulator" | head -1 | sed 's/.*• //' | sed 's/ •.*//' | tr -d ' ')
if [ -n "$ANDROID_DEVICE" ]; then
    echo "Android Device ID: $ANDROID_DEVICE"
    flutter run -d "$ANDROID_DEVICE" &
    ANDROID_PID=$!
else
    echo "No Android emulator found, skipping..."
fi

echo ""
echo "========================================"
echo "  All platforms started!"
echo "========================================"
echo ""
echo "Running processes:"
[ -n "$MACOS_PID" ] && echo "  - macOS (PID: $MACOS_PID)"
[ -n "$IOS_PID" ] && echo "  - iOS Simulator (PID: $IOS_PID)"
[ -n "$ANDROID_PID" ] && echo "  - Android (PID: $ANDROID_PID)"
echo ""
echo "Press Ctrl+C to stop all..."

wait