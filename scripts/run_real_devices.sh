#!/bin/bash
# EchoLink 运行脚本 - 仅真机设备
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"
export JAVA_HOME="$HOME/jdk/zulu-17.jdk/Contents/Home"
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export http_proxy=""
export https_proxy=""

cd "$PROJECT_DIR"

echo "========================================"
echo "  EchoLink - 真机设备"
echo "========================================"
echo ""

# 检测 iPhone
echo "检测 iPhone..."
IOS_DEVICE=$(xcrun devicectl list devices 2>/dev/null | grep -i "iphone" | head -1)
IOS_DEVICE_ID=$(echo "$IOS_DEVICE" | awk '{print $4}')

# 检测 Android
echo "检测 Android..."
ANDROID_DEVICE=$(adb devices | grep -v "List" | grep "device$" | grep -v "emulator" | head -1)
ANDROID_DEVICE_ID=$(echo "$ANDROID_DEVICE" | awk '{print $1}')

echo ""
echo "检测到的设备:"
[ -n "$IOS_DEVICE_ID" ] && echo "  iPhone: $IOS_DEVICE_ID"
[ -n "$ANDROID_DEVICE_ID" ] && echo "  Android: $ANDROID_DEVICE_ID"
[ -z "$IOS_DEVICE_ID" ] && [ -z "$ANDROID_DEVICE_ID" ] && echo "  未检测到真机设备"
echo ""

# 构建
echo "构建应用..."
flutter build apk --release 2>&1 | tail -3
flutter build ios --release 2>&1 | tail -3

# 安装
if [ -n "$ANDROID_DEVICE_ID" ]; then
    echo ""
    echo "安装到 Android..."
    adb -s "$ANDROID_DEVICE_ID" install -r build/app/outputs/flutter-apk/app-release.apk
    adb -s "$ANDROID_DEVICE_ID" shell am start -n com.example.echolink/.MainActivity
fi

if [ -n "$IOS_DEVICE_ID" ]; then
    echo ""
    echo "安装到 iPhone..."
    TEAM_ID="3MYYDZX74K"
    SIGN_IDENTITY="Apple Development: QiuYe Yu (3JWGTFVRX3)"
    
    cat > /tmp/entitlements.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>${TEAM_ID}.com.example.echolink</string>
    <key>com.apple.developer.team-identifier</key>
    <string>${TEAM_ID}</string>
    <key>get-task-allow</key>
    <true/>
</dict>
</plist>
EOF
    
    for framework in build/ios/iphoneos/Runner.app/Frameworks/*; do
        [ -d "$framework" ] && codesign --force --sign "$SIGN_IDENTITY" "$framework" 2>/dev/null || true
    done
    codesign --force --sign "$SIGN_IDENTITY" --entitlements /tmp/entitlements.plist build/ios/iphoneos/Runner.app
    
    xcrun devicectl device install app --device "$IOS_DEVICE_ID" build/ios/iphoneos/Runner.app
    echo "请在 iPhone 上手动打开应用"
fi

echo ""
echo "启动 macOS..."
flutter run -d macos --release --no-pub 2>&1 &

echo ""
echo "========================================"
echo "  完成"
echo "========================================"