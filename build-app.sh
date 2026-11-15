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
# เลขรุ่นมาจาก project.yml (ที่เดียว) · build ในเครื่องใช้เลข build "0"
VER=$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)".*/\1/p' "$ROOT/project.yml")
[[ -n "$VER" ]] || { echo "อ่าน MARKETING_VERSION จาก project.yml ไม่ได้" >&2; exit 1; }
sed -e "s/\$(MARKETING_VERSION)/$VER/" -e "s/\$(CURRENT_PROJECT_VERSION)/0/" \
  "$ROOT/Resources/Info.plist" > "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"
# คำแปล: String Catalog → <lang>.lproj (แอปเปิด lproj ตามภาษาที่เลือกในแอปเอง)
xcrun xcstringstool compile "$ROOT/Resources/Localizable.xcstrings" --output-directory "$APP/Contents/Resources"
codesign --force --sign - "$APP"
echo "built: $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x MojoCalendarBar || true
  rm -rf /Applications/MojoCalendarBar.app
  cp -R "$APP" /Applications/
  open /Applications/MojoCalendarBar.app
  echo "installed: /Applications/MojoCalendarBar.app"
fi
