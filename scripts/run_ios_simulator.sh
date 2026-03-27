#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"

echo "========================================"
echo "  EchoLink - iOS Simulator Build & Run"
echo "========================================"
echo ""

cd "$PROJECT_DIR"

echo "[1/3] Getting dependencies..."
flutter pub get

echo ""
echo "[2/3] Checking for iOS Simulator..."
DEVICE_ID=$(flutter devices 2>/dev/null | grep -i "iphone.*simulator" | head -1 | awk '{print $3}')

if [ -z "$DEVICE_ID" ]; then
    echo "No iOS Simulator found. Starting one..."
    open -a Simulator
    sleep 5
    DEVICE_ID=$(flutter devices 2>/dev/null | grep -i "iphone.*simulator" | head -1 | awk '{print $3}')
fi

if [ -z "$DEVICE_ID" ]; then
    echo "ERROR: No iOS Simulator available"
    exit 1
fi

echo "Using device: $DEVICE_ID"

echo ""
echo "[3/3] Running on iOS Simulator..."
flutter run -d "$DEVICE_ID"

echo ""
echo "Done!"