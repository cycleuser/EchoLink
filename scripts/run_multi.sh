#!/bin/bash
# EchoLink 多设备同时运行 - 用于网络发现测试

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
echo "  EchoLink - 多设备同时运行"
echo "========================================"
echo ""

# 获取设备列表
DEVICES=$(flutter devices 2>/dev/null)

# 收集所有设备ID
declare -a ALL_DEVICES
declare -a ALL_NAMES

# macOS
if echo "$DEVICES" | grep -q "macos.*desktop"; then
    ALL_DEVICES+=("macos")
    ALL_NAMES+=("macOS")
fi

# iOS 真机
IOS_REAL=$(echo "$DEVICES" | grep -E "iPhone.*mobile.*ios" | grep -v "Simulator" | grep -v "simulator")
if [ -n "$IOS_REAL" ]; then
    IOS_ID=$(echo "$IOS_REAL" | awk '{print $3}' | tr -d '•')
    IOS_NAME=$(echo "$IOS_REAL" | awk -F'•' '{print $1}' | xargs)
    ALL_DEVICES+=("$IOS_ID")
    ALL_NAMES+=("$IOS_NAME")
fi

# iOS 模拟器
IOS_SIM=$(echo "$DEVICES" | grep -E "simulator.*ios" | head -1)
if [ -n "$IOS_SIM" ]; then
    IOS_SIM_ID=$(echo "$IOS_SIM" | awk '{print $3}' | tr -d '•')
    ALL_DEVICES+=("$IOS_SIM_ID")
    ALL_NAMES+=("iOS模拟器")
fi

# Android 真机
ANDROID_REAL=$(echo "$DEVICES" | grep -E "mobile.*android" | grep -v "emulator")
if [ -n "$ANDROID_REAL" ]; then
    ANDROID_ID=$(echo "$ANDROID_REAL" | awk '{print $3}' | tr -d '•')
    ALL_DEVICES+=("$ANDROID_ID")
    ALL_NAMES+=("Android真机")
fi

# Android 模拟器
ANDROID_EMU=$(echo "$DEVICES" | grep -E "emulator.*android")
if [ -n "$ANDROID_EMU" ]; then
    EMU_ID=$(echo "$ANDROID_EMU" | awk '{print $3}' | tr -d '•')
    ALL_DEVICES+=("$EMU_ID")
    ALL_NAMES+=("Android模拟器")
fi

DEVICE_COUNT=${#ALL_DEVICES[@]}

if [ $DEVICE_COUNT -eq 0 ]; then
    echo "错误: 未检测到任何设备"
    exit 1
fi

echo "检测到 $DEVICE_COUNT 个设备:"
for i in "${!ALL_DEVICES[@]}"; do
    echo "  $((i+1)). ${ALL_NAMES[$i]} (${ALL_DEVICES[$i]})"
done
echo ""

# 先构建一次
echo "正在构建..."
flutter build macos --debug 2>/dev/null || true
flutter build ios --debug --no-codesign 2>/dev/null || true

echo ""
echo "启动所有设备..."
echo ""

# 启动所有设备
for i in "${!ALL_DEVICES[@]}"; do
    DEVICE_ID="${ALL_DEVICES[$i]}"
    DEVICE_NAME="${ALL_NAMES[$i]}"
    
    echo "启动: $DEVICE_NAME"
    flutter run -d "$DEVICE_ID" --no-pub 2>&1 | sed "s/^/[$DEVICE_NAME] /" &
done

echo ""
echo "所有设备已启动!"
echo "等待设备互相发现..."
echo ""

# 等待所有进程
wait