#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"
export JAVA_HOME="$HOME/jdk/zulu17.54.21-ca-jdk17.0.13-macosx_aarch64/zulu-17.jdk/Contents/Home"
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

echo "========================================"
echo "  EchoLink - Android Emulator Build & Run"
echo "========================================"
echo ""

cd "$PROJECT_DIR"

echo "[1/4] Getting dependencies..."
flutter pub get

echo ""
echo "[2/4] Checking for Android emulator..."
EMULATOR_DEVICE=$(flutter devices 2>/dev/null | grep -i "emulator" | head -1 | awk '{print $3}')

if [ -z "$EMULATOR_DEVICE" ]; then
    echo "No running emulator found. Checking for available emulators..."
    AVAILABLE_EMULATORS=$($ANDROID_HOME/emulator/emulator -list-avds 2>/dev/null | head -1)
    
    if [ -z "$AVAILABLE_EMULATORS" ]; then
        echo "ERROR: No Android emulator found"
        echo "Please create an emulator in Android Studio first"
        exit 1
    fi
    
    echo "Starting emulator: $AVAILABLE_EMULATORS"
    $ANDROID_HOME/emulator/emulator -avd "$AVAILABLE_EMULATORS" -no-sound -no-audio -no-boot-anim -accel on &
    
    echo "Waiting for emulator to boot..."
    sleep 30
    
    EMULATOR_DEVICE=$(flutter devices 2>/dev/null | grep -i "emulator" | head -1 | awk '{print $3}')
fi

if [ -z "$EMULATOR_DEVICE" ]; then
    echo "ERROR: Could not get emulator device ID"
    exit 1
fi

echo "Using emulator: $EMULATOR_DEVICE"

echo ""
echo "[3/4] Building Android APK..."
flutter build apk --debug

echo ""
echo "[4/4] Running on emulator..."
flutter run -d "$EMULATOR_DEVICE"

echo ""
echo "Done!"