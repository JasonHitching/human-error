"""Dev tool: pack every sprite in a folder into one contact sheet (needs Pillow).
usage: python3 contact_sheet.py <spriteDir> <out.png> [width=1600]"""
import sys, glob, os
from PIL import Image, ImageDraw
d, out = sys.argv[1], sys.argv[2]; W = int(sys.argv[3]) if len(sys.argv) > 3 else 1600
fs = [f for f in sorted(glob.glob(d + '/*.png')) if os.path.basename(f)[:-4].split('_')[0] in ('machine','desk','scrap','reject','belt','floor','wall','fence','crate','bot','worker','shadow')]
ims = [(os.path.basename(f)[:-4], Image.open(f).convert('RGBA')) for f in fs]
pad, x, y, rowh, placed = 12, pad if (pad := 12) else 0, 12, 0, []
for n, i in ims:
    if x + i.width + pad > W: x, y, rowh = pad, y + rowh + 30, 0
    placed.append((n, i, x, y)); x += i.width + pad; rowh = max(rowh, i.height)
H = y + rowh + 30 + 200
S = Image.new('RGBA', (W, H), (36, 39, 48, 255)); dr = ImageDraw.Draw(S)
for n, i, px, py in placed:
    S.alpha_composite(i, (px, py + 14)); dr.text((px, py), n, fill=(190, 196, 210, 255))
# 25% strip
sx, sy = 12, y + rowh + 30
dr.text((sx, sy - 14), 'same sprites at 25%', fill=(190, 196, 210, 255))
for n, i, px, py in placed:
    t = i.resize((max(1, i.width // 4), max(1, i.height // 4)), Image.LANCZOS)
    if sx + t.width > W - 12: sx, sy = 12, sy + 90
    S.alpha_composite(t, (sx, sy)); sx += t.width + 6
S.crop((0, 0, W, min(H, sy + 100))).convert('RGB').save(out)
