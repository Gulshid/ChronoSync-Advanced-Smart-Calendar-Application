"""Generates the ChronoSync app icon.

Outputs (1024 x 1024):
  assets/icon/icon.png             full-colour icon (iOS and legacy Android)
  assets/icon/icon_foreground.png  transparent foreground for Android adaptive icons

Run from the project root:  python3 tools/make_icon.py
"""
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 2                      # supersampling factor for smooth edges
W = SIZE * SS

INDIGO_TOP = (61, 107, 255)
INDIGO_BOTTOM = (27, 63, 196)
TEAL = (18, 163, 138)
ORANGE = (232, 131, 58)
WHITE = (255, 255, 255)
GRID = (227, 232, 245)
RING = (14, 42, 140)


def gradient_background():
    img = Image.new("RGB", (W, W))
    px = img.load()
    for y in range(W):
        for x in range(W):
            t = (x + y) / (2 * W)
            px[x, y] = tuple(
                round(INDIGO_TOP[i] + (INDIGO_BOTTOM[i] - INDIGO_TOP[i]) * t) for i in range(3)
            )
    return img.convert("RGBA")


def rounded(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def draw_calendar(layer, scale, cx, cy, with_shadow):
    """Draws the calendar card centred on (cx, cy) at the given scale."""
    def s(v):
        return v * scale * SS

    card_w, card_h = s(624), s(600)
    left = cx - card_w / 2
    top = cy - card_h / 2
    right = left + card_w
    bottom = top + card_h
    radius = s(60)
    header_h = s(150)

    if with_shadow:
        shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        off = s(16)
        rounded(sd, (left, top + off, right, bottom + off), radius, (8, 20, 70, 90))
        shadow = shadow.filter(ImageFilter.GaussianBlur(s(18)))
        layer.alpha_composite(shadow)

    d = ImageDraw.Draw(layer)

    # Card body
    rounded(d, (left, top, right, bottom), radius, WHITE)

    # Teal header band, flat at the bottom so it joins the body cleanly
    d.rounded_rectangle((left, top, right, top + header_h + radius), radius=radius, fill=TEAL)
    d.rectangle((left, top + header_h, right, top + header_h + radius), fill=WHITE)
    d.rectangle((left, top + header_h, right, top + header_h + 1), fill=TEAL)
    d.rectangle((left, top + header_h - s(2), right, top + header_h + s(2)), fill=TEAL)
    d.rectangle((left, top + header_h - s(2), right, top + header_h - s(1)), fill=TEAL)

    # Binder rings
    ring_w, ring_h = s(46), s(128)
    for rx in (left + card_w * 0.30, left + card_w * 0.70):
        rounded(d, (rx - ring_w / 2, top - s(44), rx + ring_w / 2, top + s(84)), s(23), WHITE)
        rounded(d, (rx - ring_w / 2 + s(10), top - s(30), rx + ring_w / 2 - s(10), top + s(70)), s(13), RING)

    # Day grid: 4 columns x 3 rows, one highlighted day with a check mark
    cols, rows = 4, 3
    grid_left = left + s(70)
    grid_top = top + header_h + s(56)
    cell = s(104)
    gap = s(34)
    size = s(68)
    for r in range(rows):
        for c in range(cols):
            x = grid_left + c * (cell + gap)
            y = grid_top + r * (cell + gap)
            box = (x, y, x + size, y + size)
            if (r, c) == (1, 1):
                rounded(d, box, s(20), ORANGE)
                cx_, cy_ = x + size / 2, y + size / 2
                k = s(0.8)
                pts = [
                    (cx_ - s(16) * k, cy_ + s(1) * k),
                    (cx_ - s(4) * k, cy_ + s(13) * k),
                    (cx_ + s(18) * k, cy_ - s(12) * k),
                ]
                d.line(pts, fill=WHITE, width=round(s(8)), joint="curve")
            else:
                rounded(d, box, s(20), GRID)


def finish(img):
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    # Full icon: gradient background + card
    base = gradient_background()
    draw_calendar(base, scale=1.0, cx=W / 2, cy=W / 2 + SS * 12, with_shadow=True)
    finish(base.convert("RGB")).save("assets/icon/icon.png", optimize=True)

    # Adaptive foreground: transparent, card scaled to sit inside the 66% safe zone
    fg = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    draw_calendar(fg, scale=0.76, cx=W / 2, cy=W / 2, with_shadow=True)
    finish(fg).save("assets/icon/icon_foreground.png", optimize=True)
    print("wrote assets/icon/icon.png and assets/icon/icon_foreground.png")


if __name__ == "__main__":
    main()
