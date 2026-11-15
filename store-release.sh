#!/bin/zsh
# ส่ง build ขึ้น Mac App Store (App Store Connect · แอป 6835091274)
#   ./store-release.sh            → xcodegen → archive (universal) → ตรวจ → export+upload
#   ./store-release.sh --no-upload → หยุดที่ .pkg ใน build-store/export/ (ไม่ส่ง Apple)
# เลขรุ่น = MARKETING_VERSION ใน project.yml · เลข build = เวลาตอนรัน (YYYYMMDDHHMM ไม่ซ้ำเอง)
# เซ็นแบบ manual (คีย์ API ไม่มีสิทธิ์ใบเซ็นคลาวด์): "Apple Distribution" + "3rd Party Mac Developer Installer" ใน login keychain
#   + profile "Mojo Calendar Bar MAS" (MAC_APP_STORE) — สร้างผ่าน API 15 พ.ย. 2569 · กุญแจ installer อยู่ ~/.config/mojozoft-signing/
# คีย์ API (App Manager) ใช้ใบเดียวกับ Ginzii — ⛔ ไม่ commit .p8 · override ได้ด้วย env ASC_KEY_ID/ASC_ISSUER_ID/ASC_KEY_PATH
set -euo pipefail
ROOT="${0:A:h}"
cd "$ROOT"

UPLOAD=1
[[ "${1:-}" == "--no-upload" ]] && UPLOAD=0

: "${ASC_KEY_ID:=ZG6JV24ALB}"
: "${ASC_ISSUER_ID:=9dda27e5-3ef1-4c3b-a00d-10c7f841dc3c}"
: "${ASC_KEY_PATH:=$HOME/Library/CloudStorage/GoogleDrive-lojorider@gmail.com/My Drive/work/ios-app/key-ios/AuthKey_${ASC_KEY_ID}.p8}"
[[ -f "$ASC_KEY_PATH" ]] || { echo "ไม่เจอคีย์ $ASC_KEY_PATH" >&2; exit 1; }

OUT="$ROOT/build-store"
BUILD=$(date +%Y%m%d%H%M)
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

rm -rf "$OUT"; mkdir -p "$OUT"
xcodegen generate --quiet

echo "▶ archive (build $BUILD)"
xcodebuild -project MojoCalendarBar.xcodeproj -scheme MojoCalendarBar -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$OUT/MojoCalendarBar.xcarchive" \
  CURRENT_PROJECT_VERSION="$BUILD" "${AUTH[@]}" archive > "$OUT/archive.log" 2>&1 \
  || { tail -30 "$OUT/archive.log"; echo "❌ archive ล้ม — ดู $OUT/archive.log" >&2; exit 1; }

# ด่านตรวจก่อนส่ง Apple
APP="$OUT/MojoCalendarBar.xcarchive/Products/Applications/MojoCalendarBar.app"
lipo -archs "$APP/Contents/MacOS/MojoCalendarBar" | grep -q x86_64 || { echo "❌ ไม่ใช่ universal" >&2; exit 1; }
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q app-sandbox || { echo "❌ ไม่มี app-sandbox" >&2; exit 1; }
for f in PrivacyInfo.xcprivacy th.lproj en.lproj AppIcon.icns; do
  [[ -e "$APP/Contents/Resources/$f" ]] || { echo "❌ ขาด $f" >&2; exit 1; }
done
echo "✅ ตรวจผ่าน: universal · sandbox · PrivacyInfo · lproj · icon · $(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist") ($BUILD)"

DEST=export  # อัปด้วย altool ข้างล่าง (export แบบ upload ต้องใช้ใบเซ็นคลาวด์ ซึ่งคีย์ API ไม่มีสิทธิ์)
cat > "$OUT/ExportOptions.plist" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$DEST</string>
  <key>teamID</key><string>KVQVC98SC8</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>installerSigningCertificate</key><string>3rd Party Mac Developer Installer</string>
  <key>provisioningProfiles</key><dict>
    <key>com.mojozoft.calendarbar</key><string>Mojo Calendar Bar MAS</string>
  </dict>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLISTEOF

echo "▶ export ($DEST)"
xcodebuild -exportArchive -archivePath "$OUT/MojoCalendarBar.xcarchive" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -exportPath "$OUT/export" "${AUTH[@]}" \
  > "$OUT/export.log" 2>&1 || { tail -30 "$OUT/export.log"; echo "❌ export ล้ม — ดู $OUT/export.log" >&2; exit 1; }

PKG="$OUT/export/MojoCalendarBar.pkg"
[[ -f "$PKG" ]] || { echo "❌ ไม่มี $PKG" >&2; exit 1; }
# altool หาไฟล์คีย์จาก ~/.appstoreconnect/private_keys เท่านั้น
mkdir -p ~/.appstoreconnect/private_keys
ln -sf "$ASC_KEY_PATH" ~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8
ALT=(-t macos --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID")
echo "▶ validate"
xcrun altool --validate-app -f "$PKG" "${ALT[@]}" > "$OUT/validate.log" 2>&1
grep -q "VERIFY SUCCEEDED" "$OUT/validate.log" || { tail -20 "$OUT/validate.log"; echo "❌ validate ไม่ผ่าน" >&2; exit 1; }
if (( UPLOAD )); then
  echo "▶ upload"
  xcrun altool --upload-app -f "$PKG" "${ALT[@]}" > "$OUT/upload.log" 2>&1
  # ⚠️ บรรทัด "ERROR ... CDUploaderStateInfoResumeFilePath" มาเสมอ ไม่มีผล — ดูแค่ UPLOAD SUCCEEDED
  grep -q "UPLOAD SUCCEEDED" "$OUT/upload.log" || { tail -20 "$OUT/upload.log"; echo "❌ upload ล้ม" >&2; exit 1; }
  echo "✅ อัปโหลดแล้ว build $BUILD — Apple ประมวลผล 5–30 นาที แล้วจะขึ้นใน App Store Connect"
else
  echo "✅ validate ผ่าน · ไม่อัป (--no-upload) · $PKG"
fi
