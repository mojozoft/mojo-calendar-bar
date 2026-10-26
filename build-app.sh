#!/bin/zsh
# build .app แล้ว (ถ้าใส่ --install) ก๊อปไป /Applications
set -euo pipefail
ROOT="${0:A:h}"
cd "$ROOT"

swift build -c release
APP="$ROOT/build/MojoCalendarBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/MojoCalendarBar" "$APP/Contents/MacOS/"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "built: $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x MojoCalendarBar || true
  rm -rf /Applications/MojoCalendarBar.app
  cp -R "$APP" /Applications/
  open /Applications/MojoCalendarBar.app
  echo "installed: /Applications/MojoCalendarBar.app"
fi
