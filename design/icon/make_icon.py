#!/usr/bin/env python3
"""สร้าง AppIcon.icns จากโลโก้ตัวจริง (แบบ T · ช่องมน 3×3 + หัวจาง)
รัน: python3 design/icon/make_icon.py  → Resources/AppIcon.icns
ตัวเลขทั้งหมดอยู่ใน viewBox 100 เหมือน FINAL() ใน design/logo/index.html — แก้ต้องแก้ทั้งสองที่"""
import os, subprocess, shutil, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "design/icon"
OR = "#F26A1B"

def mark_body():
    n, area, gap, y0 = 3, 56, 6, 34
    size = (area - gap*(n-1)) / n
    x0 = (100 - area) / 2
    s = f'<rect width="100" height="100" rx="22.4" fill="{OR}"/>'
    s += '<path d="M0,22.4A22.4,22.4 0 0 1 22.4,0H77.6A22.4,22.4 0 0 1 100,22.4V25H0Z" fill="#fff" fill-opacity=".2"/>'
    for i in range(n):
        for j in range(n):
            on = i == 1 and j == 1
            s += (f'<rect x="{x0+i*(size+gap):.2f}" y="{y0+j*(size+gap):.2f}" width="{size:.2f}" height="{size:.2f}" '
                  f'rx="{size*0.28:.2f}" fill="#fff" fill-opacity="{1 if on else .45}"/>')
    return s

# กรอบ macOS: ผืน 1024 · ตัวไอคอน 824 วางที่ (100,100) · เงาใต้
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs><filter id="sh" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feGaussianBlur stdDeviation="12"/></filter></defs>
<rect x="100" y="112" width="824" height="824" rx="184.6" fill="#000" fill-opacity=".28" filter="url(#sh)"/>
<g transform="translate(100,100) scale(8.24)">{mark_body()}</g></svg>'''
(OUT / "AppIcon-1024.svg").write_text(svg)

iconset = OUT / "AppIcon.iconset"
shutil.rmtree(iconset, ignore_errors=True); iconset.mkdir()
master = OUT / "AppIcon-1024.png"
subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024", str(OUT / "AppIcon-1024.svg"), "-o", str(master)], check=True)
for base in [16, 32, 128, 256, 512]:
    for scale in [1, 2]:
        px = base * scale
        name = f"icon_{base}x{base}{'@2x' if scale == 2 else ''}.png"
        subprocess.run(["sips", "-z", str(px), str(px), str(master), "--out", str(iconset / name)],
                       check=True, capture_output=True)
(ROOT / "Resources").mkdir(exist_ok=True)
subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ROOT / "Resources/AppIcon.icns")], check=True)
print("ok", ROOT / "Resources/AppIcon.icns")
