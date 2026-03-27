#!/bin/bash
# EchoLink 运行 iOS 设备 - 自动检测

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

cd "$PROJECT_DIR"

echo "========================================"
echo "  EchoLink - iOS 设备"
echo "========================================"
echo ""

echo "检测 iOS 设备..."
DEVICES=$(flutter devices 2>/dev/null)

# 优先真机
IOS_DEVICE=$(echo "$DEVICES" | grep -E "iPhone.*mobile.*ios|iPad.*mobile.*ios" | grep -v "Simulator" | grep -v "simulator" | head -1)

if [ -z "$IOS_DEVICE" ]; then
    # 尝试模拟器
    IOS_DEVICE=$(echo "$DEVICES" | grep -E "iPhone.*simulator|iPad.*simulator" | head -1)
    if [ -n "$IOS_DEVICE" ]; then
        echo "未检测到真机，使用模拟器"
    fi
fi

if [ -z "$IOS_DEVICE" ]; then
    echo "错误: 未检测到 iOS 设备"
    echo "请连接 iPhone/iPad 或启动模拟器"
    exit 1
fi

DEVICE_ID=$(echo "$IOS_DEVICE" | awk '{print $3}' | tr -d '•')
DEVICE_NAME=$(echo "$IOS_DEVICE" | awk -F'•' '{print $1}' | xargs)

echo "设备: $DEVICE_NAME"
echo "ID: $DEVICE_ID"
echo ""
echo "正在启动..."

flutter run -d "$DEVICE_ID" --no-pub