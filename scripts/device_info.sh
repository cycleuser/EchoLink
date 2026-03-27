#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"
export JAVA_HOME="$HOME/jdk/zulu17.54.21-ca-jdk17.0.13-macosx_aarch64/zulu-17.jdk/Contents/Home"
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

echo "========================================"
echo "  EchoLink - Device Info"
echo "========================================"
echo ""

echo "Flutter version:"
flutter --version

echo ""
echo "Available devices:"
flutter devices

echo ""
echo "Network ports in use (50505-50515):"
lsof -i :50505-50515 2>/dev/null | grep -E "(LISTEN|UDP)" || echo "No EchoLink services running"

echo ""
echo "Running EchoLink processes:"
ps aux | grep -E "(echolink|Runner)" | grep -v grep | head -10 || echo "No EchoLink processes running"

echo ""
echo "Android devices:"
adb devices 2>/dev/null || echo "ADB not available"

echo ""
echo "iOS devices:"
xcrun devicectl device list devices 2>/dev/null | head -20 || echo "No iOS devices found"