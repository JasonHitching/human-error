"""Post-bake: mute the Factory Kit's orange trim to a pale steel-blue so orange/red stays reserved for
problems and products. Usage: python3 kit_recolor.py <dir>  (all PNGs in dir, in place; needs Pillow)."""
import colorsys, glob, sys
from PIL import Image
for f in glob.glob(sys.argv[1] + "/*.png"):
    im = Image.open(f).convert("RGBA"); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.0 < h < 0.14 and s > 0.28 and v > 0.12:  # orange / amber
                r2, g2, b2 = colorsys.hsv_to_rgb(0.62, 0.22, min(1.0, v * 0.95))
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    im.save(f)
