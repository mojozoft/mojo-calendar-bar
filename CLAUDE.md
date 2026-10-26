# mojo-calendar-bar — คู่มือสำหรับ Claude

ปฏิทินบนแถบเมนู macOS ภาษาไทย/อังกฤษ สลับ พ.ศ./ค.ศ. · ของ Mojozoft · repo `github.com/mojozoft/mojo-calendar-bar` (public · PolyForm Noncommercial)

**เปิด session ใหม่ ⇒ อ่าน `BOARD.md` (สถานะ + งานถัดไป · ไฟล์ในเครื่องเท่านั้น ไม่อยู่ใน git — มีแผนขาย) แล้วอ่าน `README.md` §กับดัก ก่อนแก้โค้ด**

## Build / ติดตั้ง
```bash
./build-app.sh            # swift build + ห่อ build/MojoCalendarBar.app (ไม่ต้องเปิด Xcode)
./build-app.sh --install  # ปิดตัวเก่า → ก๊อปไป /Applications → เปิด (ตัวที่เจ้าของใช้จริง)
python3 design/icon/make_icon.py   # สร้าง Resources/AppIcon.icns ใหม่ (ถ้าแก้โลโก้)
```
ทดสอบ logic วันที่แบบไม่ต้องเปิดแอป: ก๊อป `ThaiDate.swift` + `main.swift` เล็ก ๆ ไป scratchpad แล้ว `swiftc` (ดูประวัติ session 21ต.ค.69)

## โครงไฟล์
| ไฟล์ | หน้าที่ |
|---|---|
| `Sources/.../App.swift` | MenuBarExtra · ไอคอนแถบเมนู (เลขวันเจาะในกรอบทึบมน) · DayClock (ข้ามวัน/ตื่นจากหลับ) · launch at login |
| `Sources/.../CalendarView.swift` | หน้าต่างปฏิทิน · ค่าที่จำไว้ใช้ `@AppStorage` (`era` `lang` `titleFormat` `showWeekNumbers`) |
| `Sources/.../ThaiDate.swift` | `Era` · `Lang` (ข้อความทุกคำบนจอ ไทย/อังกฤษ) · จัดรูปแบบวันที่ — คำนวณ Gregorian เสมอแล้ว +543 |
| `Sources/.../Glass.swift` | ทำพื้นหน้าต่างเป็น Liquid Glass (ส่วนที่เปราะที่สุด — อ่านคอมเมนต์ก่อนแตะ) |
| `design/logo/index.html` | หน้าเทียบโลโก้ทุกแบบ A–T · `FINAL()` = ตัวจริง |

## วิธีทำงานกับเจ้าของ (เรียนจาก session แรก)
- เจ้าของสั่งปรับ **ทีละจุดจากภาพหน้าจอ** (ลูกศรแดงชี้) ⇒ แก้จุดนั้น → build → **ถ่ายภาพยืนยันเองก่อนรายงาน**
- ถ่ายภาพ popover: หาตำแหน่งไอคอนด้วย `osascript ... menu bar item 1 of menu bar 2` → `cliclick` → `screencapture -R`
  ⚠️ **การคลิกชนกับเจ้าของที่ใช้จอเดียวกัน** (เคยกดปุ่มสลับภาษาซ้อนกันจนค่ากลับไปกลับมา) ⇒ ถ้าเจ้าของกำลังกดอยู่ ให้เจ้าของลองเอง
- ตั้งค่าเพื่อทดสอบ: `defaults write com.mojozoft.calendarbar <key> ...` ตอนแอปปิดอยู่ · คืนค่าให้เจ้าของหลังทดสอบ
- ชอบหน้าตาแบบเมนูระบบ (glass) · ปุ่มเป็นไอคอน · ไม่ชอบข้อความรก (ตัดบรรทัดปี/สัปดาห์ออกแล้ว)
- commit ทุกการแก้ · push หลังเสร็จแต่ละเรื่อง (`git push` แล้วเช็ค `git log -1 origin/main`)
