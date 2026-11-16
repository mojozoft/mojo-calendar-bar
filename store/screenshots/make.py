"""ทำภาพหน้าจอ Mac App Store 2560×1600 (วางเลย์เอาต์ 1280×800 แล้วถ่ายที่ scale 2) จากภาพดิบ 2x ใน src/

  python3 store/screenshots/make.py   → store/screenshots/<locale>/0N.png

ภาพดิบ (ถ่าย 17 พ.ย. 69 บนจอ Retina · `screencapture -o -l<windowID>` = เฉพาะหน้าต่าง ไม่มีเงา):
  · popover: <th|en>_hero (ถิ่นไทย) · ja/de/zh/en_us (เปิดแอปด้วย -AppleLocale ของประเทศนั้น)
  · หน้าต่างตั้งค่า: <th|en>_<general|icon|thai|about>
  · src/icons/: ไอคอนแถบเมนูเรนเดอร์จาก MenuIcon.swift ที่ 2x (<loc>_<a-f|hero>_<light|dark>.png)
⚠️ ตอนถ่าย popover ต้องมีพื้นทึบบังหน้าต่างอื่น (กระจกเบลอของข้างหลัง — เคยติดข้อความ terminal)
แถบเมนูในภาพวาดด้วย HTML (ไม่ใช้แถบจริง — มีไอคอนแอปอื่นของเครื่องติดมา)
"""
import os, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'src')
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
W, H = 1280, 800  # หน่วย CSS · ไฟล์จริง ×2

# (หัวข้อ, คำโปรย, ชนิดภาพ)
SLIDES = {
    'en-US': {
        'clock': 'Tue 17 Nov  9:41',
        'slides': [
            ('Thai lunar calendar<br>in your menu bar', 'Buddhist holy days · waxing &amp; waning moon<br>Thai holidays · Buddhist Era or AD', 'hero'),
            ('Make the icon<br>your own', 'Filled, outline or no background<br>9 colors · day, month and year', 'icons'),
            ('Any year system.<br>10 languages.', 'Gregorian · Buddhist Era · Reiwa · Minguo<br>Week starts the way your region does', 'langs'),
            ('Everything in<br>one Settings window', 'Turn holy days, holidays and lunar dates<br>on or off · open at login · week numbers', 'settings'),
        ],
    },
    'th': {
        'clock': 'อ. 17 พ.ย.  9:41',
        'slides': [
            ('ปฏิทินไทย<br>บนแถบเมนู Mac', 'วันพระ · ข้างขึ้นข้างแรม · วันหยุดไทย<br>สลับ พ.ศ. / ค.ศ. ในคลิกเดียว', 'hero'),
            ('แต่งไอคอน<br>ได้ตามใจ', 'มีพื้น · กรอบเส้น · ไม่มีพื้น · 9 สี<br>วันที่ · เดือน · ปีย่อหรือปีเต็ม', 'icons'),
            ('ทุกระบบปี<br>10 ภาษา', 'พ.ศ. · ค.ศ. · ปีญี่ปุ่น · ปีไต้หวัน<br>วันเริ่มสัปดาห์ตามประเทศ', 'langs'),
            ('ตั้งค่าครบ<br>ในหน้าต่างเดียว', 'เปิด/ปิด วันพระ วันหยุด ข้างขึ้นข้างแรม แยกกัน<br>เปิดเองตอนเข้าเครื่อง · เลขสัปดาห์', 'settings'),
        ],
    },
}

CSS = f'''
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{ width: {W}px; height: {H}px; overflow: hidden; }}
body {{ font-family: -apple-system, "SF Pro Display", "Sukhumvit Set", sans-serif; color: #fff; position: relative;
  background: linear-gradient(135deg, #f98c40 0%, #8c3f9e 50%, #1f3373 100%); }}
.text {{ position: absolute; left: 72px; top: 0; bottom: 0; width: 470px; display: flex; flex-direction: column; justify-content: center; }}
h1 {{ font-size: 56px; line-height: 1.12; font-weight: 800; letter-spacing: -0.5px; text-shadow: 0 2px 18px rgba(0,0,0,.25); }}
p {{ margin-top: 22px; font-size: 22px; line-height: 1.5; opacity: .92; }}
.brand {{ margin-top: 34px; font-size: 16px; font-weight: 600; opacity: .75; letter-spacing: 1px; }}
.shadow {{ filter: drop-shadow(0 18px 40px rgba(0,0,0,.4)); }}
img.x2 {{ display: block; }}

/* แถบเมนูจำลอง */
.menubar {{ position: absolute; left: 0; right: 0; top: 0; height: 30px; display: flex; align-items: center; justify-content: flex-end;
  gap: 18px; padding: 0 18px; background: rgba(20,14,40,.42); backdrop-filter: blur(20px); font-size: 14px; font-weight: 500; }}
.menubar .item {{ height: 24px; display: flex; align-items: center; padding: 0 6px; border-radius: 6px; }}
.menubar .item.on {{ background: rgba(255,255,255,.22); }}
.tpl-dark {{ filter: invert(1); }}  /* template (ดำ) → ขาวบนแถบมืด */
.pop {{ position: absolute; top: 40px; }}

/* หน้าไอคอน */
.icons-wrap {{ position: absolute; right: 64px; top: 0; bottom: 0; display: flex; align-items: center; gap: 30px; }}
.bars {{ display: flex; flex-direction: column; gap: 14px; }}
.bar {{ width: 190px; height: 44px; border-radius: 10px; display: flex; align-items: center; justify-content: center; }}
.bar.light {{ background: rgba(246,246,248,.92); }}
.bar.dark {{ background: rgba(28,24,40,.82); }}

/* หน้าภาษา */
body.langs .text {{ left: 0; right: 0; width: auto; top: 70px; bottom: auto; text-align: center; display: block; }}
body.langs h1 {{ font-size: 50px; }} body.langs p {{ margin-top: 12px; }} body.langs .brand {{ display: none; }}
.row {{ position: absolute; left: 0; right: 0; bottom: 70px; display: flex; gap: 30px; justify-content: center; align-items: flex-end; }}

/* หน้าตั้งค่า (ใช้เลย์เอาต์เดียวกับหน้าภาษา) */
.row.top {{ align-items: flex-start; bottom: auto; top: 300px; }}
'''


def img(name, scale=0.5, cls='', style=''):
    """ภาพดิบ 2x แสดงที่ครึ่งหนึ่งของพิกเซล ⇒ ในไฟล์ 2x คมเท่าของจริง"""
    path = os.path.join(SRC, name)
    w = int(subprocess.run(['sips', '-g', 'pixelWidth', path], capture_output=True, text=True).stdout.split()[-1])
    return f'<img class="x2 {cls}" style="width:{w * scale}px;{style}" src="file://{path}">'


def page(loc, title, sub, kind):
    k = 'th' if loc == 'th' else 'en'
    clock = SLIDES[loc]['clock']
    text = f'<div class="text"><h1>{title}</h1><p>{sub}</p><div class="brand">MOJO CALENDAR BAR</div></div>'
    if kind == 'hero':
        # popover (ขยาย 0.75 = 444px) ห้อยตรงใต้ไอคอนที่ถูกกด · กลาง popover = x 1280-90-222 = 968
        body = f'''<div class="menubar"><div class="item">{clock}</div></div>
<div class="item on" style="position:absolute;top:3px;left:{968 - 19}px;width:38px;justify-content:center">{img("icons/th_hero_dark.png", cls="tpl-dark")}</div>
<div class="pop shadow" style="right:90px">{img(f"{k}_hero.png", 0.75)}</div>'''
        cls = ''
    elif kind == 'icons':
        bars = ''.join(
            f'<div class="bar {m}">{img(f"icons/{k}_{v}_{m}.png", 1.0, "tpl-dark" if m == "dark" and v in "ad" else "")}</div>'
            for v, m in zip('abcdef', ['dark', 'light', 'dark', 'light', 'light', 'dark']))
        body = f'<div class="icons-wrap"><div class="bars">{bars}</div><div class="shadow">{img(f"{k}_icon.png")}</div></div>'
        cls = ''
    elif kind == 'langs':
        body = '<div class="row">' + ''.join(f'<div class="shadow">{img(n, 0.62)}</div>' for n in ['ja.png', 'de.png', 'zh.png']) + '</div>'
        cls = 'langs'
    else:  # settings: ทั่วไป + ปฏิทินไทย เรียงข้างกัน (ซ้อนกันแล้วบังแถวระบบปี)
        body = '<div class="row top">' + ''.join(f'<div class="shadow">{img(f"{k}_{n}.png")}</div>' for n in ['general', 'thai']) + '</div>'
        cls = 'langs'
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head>
<body class="{cls}">{text}{body}</body></html>'''


for loc, cfg in SLIDES.items():
    out_dir = os.path.join(HERE, loc)
    os.makedirs(out_dir, exist_ok=True)
    for n, (t, s, kind) in enumerate(cfg['slides'], 1):
        with tempfile.NamedTemporaryFile('w', suffix='.html', delete=False) as f:
            f.write(page(loc, t, s, kind))
        out = os.path.join(out_dir, f'0{n}.png')
        subprocess.run([CHROME, '--headless=new', '--hide-scrollbars', '--force-device-scale-factor=2',
                        '--allow-file-access-from-files', f'--window-size={W},{H}', f'--screenshot={out}',
                        f'file://{f.name}'], check=True, capture_output=True)
        os.unlink(f.name)
        print(out)
