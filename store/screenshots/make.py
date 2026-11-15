"""ทำภาพหน้าจอ Mac App Store 1280×800 จากภาพ popover ดิบใน src/ (ถ่ายด้วย popover จริงบนพื้นไล่สี)

  python3 store/screenshots/make.py   → store/screenshots/<locale>/0N.png

popover ดิบมีขอบ 12px รอบหน้าต่าง ⇒ ตัดด้วย clip-path inset(12px round 22px)
"""
import os, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'src')
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
W, H = 1280, 800

SLIDES = {
    'en-US': [
        ('Thai lunar calendar<br>in your menu bar', 'Buddhist holy days · waxing &amp; waning moon<br>Thai holidays · Buddhist Era or AD', ['en_hero.png']),
        ('Any year system.<br>10 languages.', 'Gregorian · Buddhist Era · Reiwa · Minguo<br>Week starts the way your region does', ['ja.png', 'de.png', 'en_ad.png']),
        ('Turn each feature<br>on or off', 'Holy days, holidays and lunar dates are<br>separate switches · week numbers · copy date', ['en_menu.png']),
    ],
    'th': [
        ('ปฏิทินไทย<br>บนแถบเมนู Mac', 'วันพระ · ข้างขึ้นข้างแรม · วันหยุดไทย<br>สลับ พ.ศ. / ค.ศ. ในคลิกเดียว', ['th_hero.png']),
        ('ทุกระบบปี<br>10 ภาษา', 'พ.ศ. · ค.ศ. · ปีญี่ปุ่น · ปีไต้หวัน<br>วันเริ่มสัปดาห์ตามประเทศ', ['ja.png', 'de.png', 'en_ad.png']),
        ('เปิด/ปิด<br>ได้ทุกอย่าง', 'วันพระ วันหยุด ข้างขึ้นข้างแรม แยกสวิตช์<br>เลขสัปดาห์ · คัดลอกวันที่', ['th_menu.png']),
    ],
}

CSS = f'''
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{ width: {W}px; height: {H}px; overflow: hidden; }}
body {{ font-family: -apple-system, "SF Pro Display", "Sukhumvit Set", sans-serif; color: #fff;
  background: linear-gradient(135deg, #f98c40 0%, #8c3f9e 50%, #1f3373 100%);
  display: flex; align-items: center; gap: 56px; padding: 0 72px; }}
.text {{ flex: 0 0 430px; }}
h1 {{ font-size: 54px; line-height: 1.12; font-weight: 800; letter-spacing: -0.5px; text-shadow: 0 2px 18px rgba(0,0,0,.25); }}
p {{ margin-top: 22px; font-size: 22px; line-height: 1.5; opacity: .92; }}
.brand {{ margin-top: 34px; font-size: 16px; font-weight: 600; opacity: .75; letter-spacing: 1px; }}
.shots {{ flex: 1; display: flex; gap: 18px; justify-content: center; align-items: flex-start; }}
.pop {{ clip-path: inset(12px round 22px); filter: drop-shadow(0 18px 40px rgba(0,0,0,.35)); margin: -12px; }}
.menu {{ clip-path: inset(12px 0 0 12px round 20px); margin: -12px 0 0 -12px; filter: drop-shadow(0 18px 40px rgba(0,0,0,.35)); }}
body.three {{ flex-direction: column; justify-content: center; gap: 40px; padding: 0 60px; }}
body.three .text {{ flex: none; text-align: center; }}
body.three h1 {{ font-size: 50px; }} body.three p {{ margin-top: 12px; }} body.three .brand {{ display: none; }}
body.three .shots {{ flex: none; gap: 30px; }}
'''


def html(title, sub, imgs):
    cls = 'three' if len(imgs) == 3 else ''
    sep = ' · ' if cls else '<br>'
    tags = ''.join(f'<img class="{"menu" if "menu" in i else "pop"}" src="file://{SRC}/{i}">' for i in imgs)
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body class="{cls}">
<div class="text"><h1>{title.replace('<br>', ' ') if cls else title}</h1><p>{sub.replace('<br>', sep)}</p><div class="brand">MOJO CALENDAR BAR</div></div>
<div class="shots">{tags}</div></body></html>'''


for loc, slides in SLIDES.items():
    out_dir = os.path.join(HERE, loc)
    os.makedirs(out_dir, exist_ok=True)
    for n, (t, s, imgs) in enumerate(slides, 1):
        with tempfile.NamedTemporaryFile('w', suffix='.html', delete=False) as f:
            f.write(html(t, s, imgs))
        out = os.path.join(out_dir, f'0{n}.png')
        subprocess.run([CHROME, '--headless=new', '--hide-scrollbars', '--force-device-scale-factor=1',
                        '--allow-file-access-from-files', f'--window-size={W},{H}', f'--screenshot={out}',
                        f'file://{f.name}'], check=True, capture_output=True)
        os.unlink(f.name)
        print(out)
