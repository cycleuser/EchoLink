#!/bin/bash
# EchoLink 智能运行脚本 - 自动检测所有设备并运行

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 环境变量
export PATH="$HOME/flutter/bin:$PATH"
export JAVA_HOME="$HOME/jdk/zulu-17.jdk/Contents/Home"
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export http_proxy=""
export https_proxy=""
export HTTP_PROXY=""
export HTTPS_PROXY=""

cd "$PROJECT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  EchoLink - 智能设备运行${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 获取所有设备
DEVICES=$(flutter devices 2>/dev/null)

# 解析设备
declare -a DEVICE_NAMES
declare -a DEVICE_IDS
declare -a DEVICE_TYPES

# macOS
if echo "$DEVICES" | grep -q "macos.*desktop"; then
    DEVICE_NAMES+=("macOS (桌面)")
    DEVICE_IDS+=("macos")
    DEVICE_TYPES+=("macos")
fi

# iPhone 真机
IPHONE_REAL=$(echo "$DEVICES" | grep -E "iPhone.*mobile.*ios" | grep -v "Simulator" | grep -v "simulator")
if [ -n "$IPHONE_REAL" ]; then
    IPHONE_ID=$(echo "$IPHONE_REAL" | awk '{print $3}' | tr -d '•' | head -1)
    IPHONE_NAME=$(echo "$IPHONE_REAL" | awk -F'•' '{print $1}' | xargs)
    DEVICE_NAMES+=("$IPHONE_NAME (真机)")
    DEVICE_IDS+=("$IPHONE_ID")
    DEVICE_TYPES+=("ios")
fi

# iPad 真机
IPAD_REAL=$(echo "$DEVICES" | grep -E "iPad.*mobile.*ios" | grep -v "Simulator" | grep -v "simulator")
if [ -n "$IPAD_REAL" ]; then
    IPAD_ID=$(echo "$IPAD_REAL" | awk '{print $3}' | tr -d '•' | head -1)
    IPAD_NAME=$(echo "$IPAD_REAL" | awk -F'•' '{print $1}' | xargs)
    DEVICE_NAMES+=("$IPAD_NAME (真机)")
    DEVICE_IDS+=("$IPAD_ID")
    DEVICE_TYPES+=("ios")
fi

# iOS 模拟器
IOS_SIM=$(echo "$DEVICES" | grep -E "iPhone.*simulator|iPad.*simulator" | head -1)
if [ -n "$IOS_SIM" ]; then
    IOS_SIM_ID=$(echo "$IOS_SIM" | awk '{print $3}' | tr -d '•' | head -1)
    IOS_SIM_NAME=$(echo "$IOS_SIM" | awk -F'•' '{print $1}' | xargs)
    DEVICE_NAMES+=("$IOS_SIM_NAME (模拟器)")
    DEVICE_IDS+=("$IOS_SIM_ID")
    DEVICE_TYPES+=("ios_sim")
fi

# Android 真机
ANDROID_REAL=$(echo "$DEVICES" | grep -E "mobile.*android" | grep -v "emulator")
if [ -n "$ANDROID_REAL" ]; then
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            ANDROID_ID=$(echo "$line" | awk '{print $3}' | tr -d '•' | head -1)
            ANDROID_NAME=$(echo "$line" | awk -F'•' '{print $1}' | xargs)
            DEVICE_NAMES+=("$ANDROID_NAME (Android真机)")
            DEVICE_IDS+=("$ANDROID_ID")
            DEVICE_TYPES+=("android")
        fi
    done <<< "$ANDROID_REAL"
fi

# Android 模拟器
ANDROID_EMU=$(echo "$DEVICES" | grep -E "emulator.*android")
if [ -n "$ANDROID_EMU" ]; then
    EMU_ID=$(echo "$ANDROID_EMU" | awk '{print $3}' | tr -d '•' | head -1)
    EMU_NAME=$(echo "$ANDROID_EMU" | awk -F'•' '{print $1}' | xargs)
    DEVICE_NAMES+=("$EMU_NAME (模拟器)")
    DEVICE_IDS+=("$EMU_ID")
    DEVICE_TYPES+=("android")
fi

# 检查是否有设备
if [ ${#DEVICE_NAMES[@]} -eq 0 ]; then
    echo -e "${RED}错误: 未检测到任何设备${NC}"
    echo ""
    echo "请确保:"
    echo "  - macOS: 无需额外配置"
    echo "  - iPhone/iPad: 连接到电脑并信任此电脑"
    echo "  - Android: 开启USB调试并连接"
    echo ""
    exit 1
fi

# 显示设备列表
echo -e "${YELLOW}检测到以下设备:${NC}"
echo ""
for i in "${!DEVICE_NAMES[@]}"; do
    echo -e "  ${GREEN}$((i+1))${NC}. ${DEVICE_NAMES[$i]}"
done
echo ""

# 如果有参数，直接使用
if [ "$1" != "" ]; then
    SELECTION="$1"
else
    # 交互式选择
    echo -e "${CYAN}请选择要运行的设备 (输入序号，多个设备用空格分隔，输入 'all' 运行全部):${NC}"
    read -r SELECTION
fi

# 处理选择
if [ "$SELECTION" = "all" ]; then
    # 运行所有设备
    echo ""
    echo -e "${YELLOW}正在所有设备上启动...${NC}"
    
    for i in "${!DEVICE_IDS[@]}"; do
        DEVICE_ID="${DEVICE_IDS[$i]}"
        DEVICE_NAME="${DEVICE_NAMES[$i]}"
        DEVICE_TYPE="${DEVICE_TYPES[$i]}"
        
        echo ""
        echo -e "${GREEN}启动: $DEVICE_NAME${NC}"
        
        flutter run -d "$DEVICE_ID" --no-pub &
    done
    
    echo ""
    echo -e "${GREEN}所有设备已启动!${NC}"
    wait
else
    # 运行选中的设备
    for num in $SELECTION; do
        idx=$((num-1))
        if [ $idx -ge 0 ] && [ $idx -lt ${#DEVICE_IDS[@]} ]; then
            DEVICE_ID="${DEVICE_IDS[$idx]}"
            DEVICE_NAME="${DEVICE_NAMES[$idx]}"
            
            echo ""
            echo -e "${GREEN}正在 $DEVICE_NAME 上启动...${NC}"
            echo -e "${BLUE}设备ID: $DEVICE_ID${NC}"
            echo ""
            
            flutter run -d "$DEVICE_ID" --no-pub
        else
            echo -e "${RED}无效的选择: $num${NC}"
        fi
    done
fi