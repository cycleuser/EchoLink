#!/bin/bash
# EchoLink 运行 macOS - 自动检测

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

cd "$PROJECT_DIR"

echo "========================================"
echo "  EchoLink - macOS"
echo "========================================"
echo ""

echo "正在启动 macOS 应用..."
flutter run -d macos --no-pub