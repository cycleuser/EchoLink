#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"

DEVICE_ID="${1:-}"

echo "========================================"
echo "  EchoLink - iOS Device Build & Run"
echo "========================================"
echo ""

cd "$PROJECT_DIR"

echo "[1/4] Getting dependencies..."
flutter pub get

echo ""
echo "[2/4] Checking for connected iOS devices..."
DEVICES=$(flutter devices 2>/dev/null | grep -i "iphone\|ipad" | grep -v "simulator" | awk '{print $3}')

if [ -z "$DEVICES" ]; then
    echo "ERROR: No iOS device connected"
    echo "Please connect your iPhone/iPad and trust this computer"
    exit 1
fi

if [ -z "$DEVICE_ID" ]; then
    echo "Available devices:"
    flutter devices 2>/dev/null | grep -i "iphone\|ipad" | grep -v "simulator"
    echo ""
    echo "Usage: $0 <device_id>"
    echo "Example: $0 00008110-0014784C3432401E"
    exit 1
fi

echo "Using device: $DEVICE_ID"

echo ""
echo "[3/4] Building for iOS device..."
flutter build ios --device-id "$DEVICE_ID" --release

echo ""
echo "[4/4] Installing on device..."
xcrun devicectl device install app --device "$DEVICE_ID" build/ios/iphoneos/Runner.app

echo ""
echo "Launching app..."
xcrun devicectl device process launch --device "$DEVICE_ID" com.example.echolink

echo ""
echo "Done! App installed and launched on device."