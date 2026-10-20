#!/usr/bin/env python3
"""Generate the Glass Deck app icon.

Draws a 2048px master at 4x supersampling, then writes:
  Resources/AppIcon.appiconset/icon_1024.png
  Resources/AppIcon.icns

Requires Pillow and numpy:
  pip install pillow numpy
  python3 tools/make_appicon.py
"""

import os
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

S = 2048
BODY = 1648
OFF = 200
R = 370

GLASS = (210, 232, 255)


def lerp_gradient(w, h, top, bottom):
    t = np.linspace(0, 1, h)[:, None]
    arr = np.zeros((h, w, 3), dtype=np.float64)
    for i in range(3):
        arr[:, :, i] = top[i] + (bottom[i] - top[i]) * t
    return arr


def radial_layer(cx, cy, radius, color, strength, power=2.0):
    yy, xx = np.mgrid[0:S, 0:S]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / radius
    a = np.clip(1 - d, 0, 1) ** power * strength
    layer = np.zeros((S, S, 4), dtype=np.float64)
    layer[:, :, 0] = color[0]
    layer[:, :, 1] = color[1]
    layer[:, :, 2] = color[2]
    layer[:, :, 3] = a
    return Image.fromarray(np.clip(layer, 0, 255).astype(np.uint8), "RGBA")


def rrect(cx, cy, w, h, r):
    return [cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2]


def mask_of(cx, cy, w, h, r):
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle(rrect(cx, cy, w, h, r), radius=r, fill=255)
    return m


def build():
    bg = lerp_gradient(S, S, (28, 40, 84), (4, 6, 14))
    canvas = Image.fromarray(bg.astype(np.uint8), "RGB").convert("RGBA")
    canvas.alpha_composite(radial_layer(0.20 * S, 0.02 * S, 0.80 * S, (78, 156, 255), 0.50, 1.7))
    canvas.alpha_composite(radial_layer(0.90 * S, 0.96 * S, 0.62 * S, (140, 92, 255), 0.26, 2.0))

    cx, cy = 1024, 1048
    W, H, RR = 1150, 790, 146

    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [cx - W / 2 + 18, cy - H / 2 + 50, cx + W / 2 + 18, cy + H / 2 + 50],
        radius=RR, fill=(1, 2, 8, 165))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(56)))

    cards = [(118, -132, 0.895, 30, 9), (58, -66, 0.947, 40, 14), (0, 0, 1.0, 62, 20)]

    for idx, (dx, dy, sc, top_a, bot_a) in enumerate(cards):
        w, h, r = W * sc, H * sc, RR * sc
        px, py = cx + dx, cy + dy

        if idx > 0:
            prev_dx, prev_dy, prev_sc = cards[idx - 1][:3]
            pw, ph, pr = W * prev_sc, H * prev_sc, RR * prev_sc
            prevx, prevy = cx + prev_dx, cy + prev_dy
            cast = Image.new("RGBA", (S, S), (0, 0, 0, 0))
            ImageDraw.Draw(cast).rounded_rectangle(
                [prevx - pw / 2 + 6, prevy - ph / 2 + 30, prevx + pw / 2 + 6, prevy + ph / 2 + 30],
                radius=pr, fill=(0, 1, 6, 120))
            canvas.alpha_composite(cast.filter(ImageFilter.GaussianBlur(30)))

        m = mask_of(px, py, w, h, r)
        yy, _ = np.mgrid[0:S, 0:S]
        t = np.clip((yy - (py - h / 2)) / h, 0, 1)
        alpha = top_a + (bot_a - top_a) * t

        layer = np.zeros((S, S, 4), dtype=np.uint8)
        layer[:, :, 0] = GLASS[0]
        layer[:, :, 1] = GLASS[1]
        layer[:, :, 2] = GLASS[2]
        layer[:, :, 3] = alpha.astype(np.uint8)
        fill = Image.fromarray(layer, "RGBA")
        fill.putalpha(Image.composite(fill.getchannel("A"), Image.new("L", (S, S), 0), m))
        canvas.alpha_composite(fill)

        rim = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(rim).rounded_rectangle(
            rrect(px, py, w, h, r), radius=r,
            outline=(255, 255, 255, 240 if idx == 2 else 140), width=4)
        rim = rim.filter(ImageFilter.GaussianBlur(1.8))
        canvas.alpha_composite(Image.composite(rim, Image.new("RGBA", (S, S), (0, 0, 0, 0)), m))

        glint = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(glint).rounded_rectangle(
            [px - w / 2 + 10, py - h / 2 + 6, px + w / 2 - 10, py - h / 2 + 15],
            radius=6, fill=(255, 255, 255, 170 if idx == 2 else 90))
        canvas.alpha_composite(
            Image.composite(glint.filter(ImageFilter.GaussianBlur(5)), Image.new("RGBA", (S, S), (0, 0, 0, 0)), m))

    front = mask_of(cx, cy, W, H, RR)

    refraction = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(refraction)
    rd.rectangle([cx - W / 2, cy - H / 2 + 40, cx - W / 2 + 6, cy + H / 2 - 40], fill=(70, 200, 255, 120))
    rd.rectangle([cx + W / 2 - 6, cy - H / 2 + 40, cx + W / 2, cy + H / 2 - 40], fill=(150, 110, 255, 110))
    canvas.alpha_composite(
        Image.composite(refraction.filter(ImageFilter.GaussianBlur(4)), Image.new("RGBA", (S, S), (0, 0, 0, 0)), front))

    streak = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(streak).polygon(
        [(cx - 640, cy + 430), (cx - 120, cy - 430), (cx + 30, cy - 430), (cx - 480, cy + 430)],
        fill=(255, 255, 255, 22))
    canvas.alpha_composite(
        Image.composite(streak.filter(ImageFilter.GaussianBlur(46)), Image.new("RGBA", (S, S), (0, 0, 0, 0)), front))

    def pill(px, py, w, h, on):
        r = h / 2
        m = mask_of(px, py, w, h, r)
        top, bot = ((108, 226, 240), (26, 152, 182)) if on else ((196, 212, 236), (146, 166, 196))
        t = np.linspace(0, 1, S)[:, None]
        arr = np.zeros((S, S, 4), dtype=np.uint8)
        for i in range(3):
            arr[:, :, i] = np.broadcast_to((top[i] + (bot[i] - top[i]) * t).astype(np.uint8), (S, S))
        arr[:, :, 3] = np.where(np.array(m) > 0, 255 if on else 40, 0).astype(np.uint8)
        body = Image.fromarray(arr, "RGBA")

        out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        out.alpha_composite(body)
        ImageDraw.Draw(out).rounded_rectangle(
            rrect(px, py, w, h, r), radius=r,
            outline=(255, 255, 255, 130 if on else 80), width=2)

        inner = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(inner).rounded_rectangle(
            [px - w / 2 + 8, py + h / 2 - 16, px + w / 2 - 8, py + h / 2 - 4],
            radius=5, fill=(0, 8, 20, 90))
        out.alpha_composite(
            Image.composite(inner.filter(ImageFilter.GaussianBlur(6)), Image.new("RGBA", (S, S), (0, 0, 0, 0)), m))

        high = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(high).rounded_rectangle(
            [px - w / 2 + 10, py - h / 2 + 5, px + w / 2 - 10, py - h / 2 + 14],
            radius=5, fill=(255, 255, 255, 80 if on else 45))
        out.alpha_composite(
            Image.composite(high.filter(ImageFilter.GaussianBlur(5)), Image.new("RGBA", (S, S), (0, 0, 0, 0)), m))

        kx = px + w / 2 - r if on else px - w / 2 + r
        ksh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(ksh).ellipse(
            [kx - r * 0.72 + 1, py - r * 0.72 + 7, kx + r * 0.72 + 1, py + r * 0.72 + 7],
            fill=(0, 6, 16, 80))
        out.alpha_composite(ksh.filter(ImageFilter.GaussianBlur(9)))
        ImageDraw.Draw(out).ellipse(
            [kx - r * 0.72, py - r * 0.72, kx + r * 0.72, py + r * 0.72], fill=(255, 255, 255, 248))
        return out

    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle(
        [cx - 250, cy - 160, cx + 250, cy + 6], radius=90, fill=(80, 208, 230, 50))
    canvas.alpha_composite(
        Image.composite(glow.filter(ImageFilter.GaussianBlur(78)), Image.new("RGBA", (S, S), (0, 0, 0, 0)), front))

    canvas.alpha_composite(pill(cx, cy - 112, 470, 128, True))
    canvas.alpha_composite(pill(cx, cy + 74, 470, 128, False))

    yy, xx = np.mgrid[0:S, 0:S]
    dist = np.sqrt((xx - S / 2) ** 2 + (yy - S / 2) ** 2) / (BODY * 0.78)
    vignette = np.clip(1 - 0.24 * np.clip(dist, 0, 1.4) ** 2.2, 0, 1)
    rgb = np.array(canvas.convert("RGB")).astype(np.float64) * vignette[:, :, None]
    rgb = np.clip(rgb + np.random.default_rng(3).normal(0, 2.0, (S, S, 1)), 0, 255)
    canvas = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")

    squircle = mask_of(S / 2, S / 2, BODY, BODY, R)
    canvas.putalpha(squircle)

    edge = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [OFF + 2, OFF + 2, OFF + BODY - 2, OFF + BODY - 2],
        radius=R - 2, outline=(255, 255, 255, 44), width=4)
    edge = edge.filter(ImageFilter.GaussianBlur(3))
    canvas.alpha_composite(Image.composite(edge, Image.new("RGBA", (S, S), (0, 0, 0, 0)), squircle))

    return canvas.resize((1024, 1024), Image.LANCZOS)


def main():
    master = build()

    appiconset = os.path.join(ROOT, "Resources", "AppIcon.appiconset")
    os.makedirs(appiconset, exist_ok=True)
    master.save(os.path.join(appiconset, "icon_1024.png"))

    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        os.makedirs(iconset)
        for name, size in [
            ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
        ]:
            master.resize((size, size), Image.LANCZOS).save(os.path.join(iconset, name))
        out = os.path.join(ROOT, "Resources", "AppIcon.icns")
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", out], check=True)

    print("wrote Resources/AppIcon.icns and Resources/AppIcon.appiconset/icon_1024.png")


if __name__ == "__main__":
    main()
