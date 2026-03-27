#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"
export JAVA_HOME="$HOME/jdk/zulu17.54.21-ca-jdk17.0.13-macosx_aarch64/zulu-17.jdk/Contents/Home"
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

echo "========================================"
echo "  EchoLink - Stop All"
echo "========================================"
echo ""

cd "$PROJECT_DIR"

echo "Stopping macOS app..."
pkill -f echolink 2>/dev/null || true

echo "Stopping iOS Simulator app..."
pkill -f "Runner.app.*iPhone" 2>/dev/null || true

echo "Stopping Flutter processes..."
pkill -f "flutter run" 2>/dev/null || true
pkill -f "flutter_tools" 2>/dev/null || true

echo "Stopping Android app on emulator..."
adb devices 2>/dev/null | grep emulator | awk '{print $1}' | while read device; do
    adb -s "$device" shell am force-stop com.example.echolink 2>/dev/null || true
done

echo "Stopping Android app on devices..."
adb devices 2>/dev/null | grep -v emulator | grep -v "List" | awk '{print $1}' | while read device; do
    if [ -n "$device" ]; then
        adb -s "$device" shell am force-stop com.example.echolink 2>/dev/null || true
    fi
done

echo ""
echo "All stopped!"