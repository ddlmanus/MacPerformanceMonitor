#!/bin/bash

# Mac 性能监控 - 打包脚本
# 用法: ./build.sh [arm64|x86_64|universal]

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Mac性能监控"
APP_BUNDLE="$PROJECT_DIR/../Mac性能监控.app"

cd "$PROJECT_DIR"

# 默认架构
ARCH="${1:-arm64}"

echo "🔨 正在编译 $ARCH 版本..."

case "$ARCH" in
    "arm64")
        swift build -c release --arch arm64
        ;;
    "x86_64")
        swift build -c release --arch x86_64
        ;;
    "universal")
        swift build -c release --arch arm64 --arch x86_64
        ;;
    *)
        echo "❌ 不支持的架构: $ARCH"
        echo "用法: $0 [arm64|x86_64|universal]"
        exit 1
        ;;
esac

echo "📦 正在打包..."

# 复制可执行文件到 App Bundle
cp ".build/release/MacPerformanceMonitor" "$APP_BUNDLE/Contents/MacOS/"

echo "✅ 编译完成！"
echo ""
echo "App Bundle 位置: $APP_BUNDLE"
echo ""

# 询问是否创建 DMG
read -p "是否创建 DMG 安装包? (y/n): " CREATE_DMG

if [ "$CREATE_DMG" = "y" ] || [ "$CREATE_DMG" = "Y" ]; then
    DMG_NAME="${APP_NAME}-${ARCH}.dmg"
    DMG_PATH="$PROJECT_DIR/$DMG_NAME"
    
    echo "📀 正在创建 DMG..."
    
    # 检查是否有 create-dmg
    if command -v create-dmg &> /dev/null; then
        create-dmg \
            --volname "$APP_NAME" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "$APP_NAME.app" 150 185 \
            --app-drop-link 450 185 \
            "$DMG_PATH" \
            "$APP_BUNDLE"
    else
        # 使用 hdiutil
        TMP_DIR=$(mktemp -d)
        cp -r "$APP_BUNDLE" "$TMP_DIR/"
        
        # 创建 Applications 快捷方式
        ln -s /Applications "$TMP_DIR/Applications"
        
        hdiutil create -volname "$APP_NAME" \
            -srcfolder "$TMP_DIR" \
            -ov -format UDZO \
            "$DMG_PATH"
        
        rm -rf "$TMP_DIR"
    fi
    
    echo "✅ DMG 创建完成: $DMG_PATH"
fi

# 询问是否部署到 Applications
read -p "是否部署到 /Applications? (y/n): " DEPLOY

if [ "$DEPLOY" = "y" ] || [ "$DEPLOY" = "Y" ]; then
    echo "🚀 正在部署..."
    pkill -f MacPerformanceMonitor 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -r "$APP_BUNDLE" "/Applications/$APP_NAME.app"
    echo "✅ 部署完成！"
    
    read -p "是否启动应用? (y/n): " LAUNCH
    if [ "$LAUNCH" = "y" ] || [ "$LAUNCH" = "Y" ]; then
        open "/Applications/$APP_NAME.app"
    fi
fi

echo ""
echo "🎉 完成！"
