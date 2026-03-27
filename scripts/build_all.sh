#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"

echo "========================================"
echo "  EchoLink - Build All Releases"
echo "========================================"
echo ""

cd "$PROJECT_DIR"

# Clean
echo "[1/6] Cleaning..."
flutter clean
flutter pub get

# macOS
echo ""
echo "[2/6] Building macOS..."
flutter build macos --release
echo "macOS: build/macos/Build/Products/Release/echolink.app"

# iOS
echo ""
echo "[3/6] Building iOS..."
flutter build ios --release
echo "iOS: build/ios/iphoneos/Runner.app"

# Android APK
echo ""
echo "[4/6] Building Android APK..."
flutter build apk --release
echo "Android APK: build/app/outputs/flutter-apk/app-release.apk"

# Android App Bundle (for Play Store)
echo ""
echo "[5/6] Building Android App Bundle..."
flutter build appbundle --release
echo "Android App Bundle: build/app/outputs/bundle/release/app-release.aab"

# Web (optional)
echo ""
echo "[6/6] Building Web..."
flutter build web --release
echo "Web: build/web/"

echo ""
echo "========================================"
echo "  All builds complete!"
echo "========================================"
echo ""
echo "Output files:"
ls -la build/macos/Build/Products/Release/*.app 2>/dev/null || true
ls -la build/ios/iphoneos/*.app 2>/dev/null || true
ls -la build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
ls -la build/app/outputs/bundle/release/*.aab 2>/dev/null || true
ls -la build/web/index.html 2>/dev/null || true