#!/bin/bash
# EchoLink 运行 Android 设备 - 自动检测

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
echo "  EchoLink - Android 设备"
echo "========================================"
echo ""

echo "检测 Android 设备..."
DEVICES=$(flutter devices 2>/dev/null)

# 优先真机
ANDROID_DEVICE=$(echo "$DEVICES" | grep -E "mobile.*android" | grep -v "emulator" | head -1)

if [ -z "$ANDROID_DEVICE" ]; then
    # 尝试模拟器
    ANDROID_DEVICE=$(echo "$DEVICES" | grep -E "emulator.*android" | head -1)
    if [ -n "$ANDROID_DEVICE" ]; then
        echo "未检测到真机，使用模拟器"
    fi
fi

if [ -z "$ANDROID_DEVICE" ]; then
    echo "错误: 未检测到 Android 设备"
    echo "请连接 Android 设备并开启 USB 调试"
    exit 1
fi

DEVICE_ID=$(echo "$ANDROID_DEVICE" | awk '{print $3}' | tr -d '•')
DEVICE_NAME=$(echo "$ANDROID_DEVICE" | awk -F'•' '{print $1}' | xargs)

echo "设备: $DEVICE_NAME"
echo "ID: $DEVICE_ID"
echo ""
echo "正在启动..."

flutter run -d "$DEVICE_ID" --no-pub