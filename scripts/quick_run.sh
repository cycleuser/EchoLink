#!/bin/bash
# EchoLink 快速运行 - 自动选择最佳设备

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

# 获取设备列表
DEVICES=$(flutter devices 2>/dev/null)

# 优先级选择: 真机 > 模拟器 > macOS
DEVICE_ID=""

# 1. 优先: iPhone 真机
IPHONE=$(echo "$DEVICES" | grep -E "iPhone.*mobile.*ios" | grep -v "Simulator" | grep -v "simulator" | head -1)
if [ -n "$IPHONE" ]; then
    DEVICE_ID=$(echo "$IPHONE" | awk '{print $3}' | tr -d '•')
    echo "检测到 iPhone 真机: $DEVICE_ID"
fi

# 2. Android 真机
if [ -z "$DEVICE_ID" ]; then
    ANDROID=$(echo "$DEVICES" | grep -E "mobile.*android" | grep -v "emulator" | head -1)
    if [ -n "$ANDROID" ]; then
        DEVICE_ID=$(echo "$ANDROID" | awk '{print $3}' | tr -d '•')
        echo "检测到 Android 真机: $DEVICE_ID"
    fi
fi

# 3. iOS 模拟器
if [ -z "$DEVICE_ID" ]; then
    IOS_SIM=$(echo "$DEVICES" | grep -E "iPhone.*simulator" | head -1)
    if [ -n "$IOS_SIM" ]; then
        DEVICE_ID=$(echo "$IOS_SIM" | awk '{print $3}' | tr -d '•')
        echo "检测到 iOS 模拟器: $DEVICE_ID"
    fi
fi

# 4. Android 模拟器
if [ -z "$DEVICE_ID" ]; then
    ANDROID_EMU=$(echo "$DEVICES" | grep -E "emulator.*android" | head -1)
    if [ -n "$ANDROID_EMU" ]; then
        DEVICE_ID=$(echo "$ANDROID_EMU" | awk '{print $3}' | tr -d '•')
        echo "检测到 Android 模拟器: $DEVICE_ID"
    fi
fi

# 5. 最后: macOS
if [ -z "$DEVICE_ID" ]; then
    if echo "$DEVICES" | grep -q "macos.*desktop"; then
        DEVICE_ID="macos"
        echo "检测到 macOS"
    fi
fi

if [ -z "$DEVICE_ID" ]; then
    echo "错误: 未检测到任何设备"
    exit 1
fi

echo "正在启动: $DEVICE_ID"
flutter run -d "$DEVICE_ID" --no-pub