#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

IOS_DEVICE_ID="00008110-0014784C3432401E"
ANDROID_DEVICE_ID="9PCAFUBUIVG6P78X"
IOS_SIGN_IDENTITY="Apple Development: QiuYe Yu (3JWGTFVRX3)"

cd "$PROJECT_DIR"

echo "=========================================="
echo "EchoLink 真机安装脚本"
echo "=========================================="

echo ""
echo "[1/4] 构建 iOS Release..."
flutter build ios --release

echo ""
echo "[2/4] 安装到 iPhone ($IOS_DEVICE_ID)..."
ios-deploy --bundle "$PROJECT_DIR/build/ios/iphoneos/Runner.app" --id "$IOS_DEVICE_ID"

echo ""
echo "[3/4] 构建 Android Release..."
flutter build apk --release

echo ""
echo "[4/4] 安装到 Android ($ANDROID_DEVICE_ID)..."

adb -s "$ANDROID_DEVICE_ID" push "$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk" /sdcard/Download/echolink.apk 2>/dev/null

adb -s "$ANDROID_DEVICE_ID" shell am start -a android.intent.action.INSTALL_PACKAGE -d file:///sdcard/Download/echolink.apk -t application/vnd.android.package-archive 2>/dev/null || true

adb -s "$ANDROID_DEVICE_ID" shell pm install -r /sdcard/Download/echolink.apk 2>/dev/null || {
    echo ""
    echo "Android 自动安装受限，请手动安装："
    echo "  手机文件管理 → Download → echolink.apk → 安装"
}

echo ""
echo "=========================================="
echo "安装完成!"
echo "  - iPhone: 请在桌面启动 EchoLink"
echo "  - Android: 如未自动安装，请手动安装 Download/echolink.apk"
echo "=========================================="