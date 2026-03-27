#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"
export JAVA_HOME="$HOME/jdk/zulu17.54.21-ca-jdk17.0.13-macosx_aarch64/zulu-17.jdk/Contents/Home"
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

echo "========================================"
echo "  EchoLink - Test Suite"
echo "========================================"
echo ""

cd "$PROJECT_DIR"

echo "[1/3] Analyzing code..."
flutter analyze

echo ""
echo "[2/3] Running unit tests..."
flutter test test/unit/ --reporter=compact

echo ""
echo "[3/3] Running widget tests..."
flutter test test/widget/ --reporter=compact

echo ""
echo "========================================"
echo "  All tests passed!"
echo "========================================"