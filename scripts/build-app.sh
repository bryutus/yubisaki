#!/bin/bash
# yubisaki.app を組み立てて dist/ に出力する（個人利用向け・ad-hoc署名のみ）。
#   scripts/build-app.sh            # Packaging/VERSION のバージョンを使用
#   scripts/build-app.sh 0.2.0      # バージョンを指定して上書き
#
# ビルド後、dist/Yubisaki.app を /Applications へドラッグ&ドロップして使う。
# ad-hoc署名はリビルドの度にハッシュが変わるため、Accessibility/Input Monitoring
# の権限を再度許可し直す必要がある。頻繁にリビルドするなら Keychain Access で
# 自己署名の永続証明書を作り、--sign - をその証明書名に差し替えると良い。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-$(cat Packaging/VERSION)}"
APP_NAME="Yubisaki"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"

echo "==> Building $APP_NAME $VERSION (release)"
swift build -c release

RELEASE_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE="$RELEASE_DIR/$APP_NAME"
RESOURCE_BUNDLE="$RELEASE_DIR/yubisaki_Yubisaki.bundle"

if [ ! -x "$EXECUTABLE" ]; then
    echo "error: executable not found at $EXECUTABLE" >&2
    exit 1
fi

echo "==> Assembling $APP_PATH"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cp "$EXECUTABLE" "$APP_PATH/Contents/MacOS/$APP_NAME"

# Contents/Resources 配下（署名可能な標準の場所）に配置する。
# Localization.swift 側でこの場所を優先的に探すようにしている。
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/"
fi

sed "s/__VERSION__/$VERSION/g" Packaging/Info.plist.template > "$APP_PATH/Contents/Info.plist"
cp Packaging/AppIcon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --verbose "$APP_PATH"

echo "==> Done: $APP_PATH"
