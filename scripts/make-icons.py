"""Draw the Our Tasks app icon as PNG files (no extra libraries needed).

Run from the project folder:  python3 scripts/make-icons.py
Writes icons/icon-512.png, icon-192.png, apple-touch-icon.png (180) and icon-32.png.

Design: the app's blue background with two to-do rows - a ticked circle with a long bar,
and an open circle with a shorter bar - like the status circles in the app.
Everything sits inside the central 80%, so phones can crop it to a circle or rounded square.
"""
import math
import os
import struct
import zlib

BLUE = (47, 91, 211)
WHITE = (255, 255, 255)


def seg_dist(px, py, ax, ay, bx, by):
    """Distance from point P to segment AB."""
    abx, aby = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * abx + (py - ay) * aby) / (abx * abx + aby * aby)))
    return math.hypot(px - (ax + t * abx), py - (ay + t * aby))


# Shapes in unit coordinates (0..1). Each is (signed distance function, colour, opacity),
# drawn in order over the background.
R = 0.115  # row circle radius


def shapes():
    row1, row2 = 0.37, 0.63
    cx = 0.30
    return [
        # Row 1: ticked circle + long bar
        (lambda x, y: math.hypot(x - cx, y - row1) - R, WHITE, 1.0),
        (lambda x, y: min(seg_dist(x, y, cx - 0.052, row1 + 0.002, cx - 0.012, row1 + 0.042),
                          seg_dist(x, y, cx - 0.012, row1 + 0.042, cx + 0.058, row1 - 0.040)) - 0.020, BLUE, 1.0),
        (lambda x, y: seg_dist(x, y, 0.495, row1, 0.775, row1) - 0.038, WHITE, 1.0),
        # Row 2: open circle + shorter bar
        (lambda x, y: abs(math.hypot(x - cx, y - row2) - (R - 0.018)) - 0.018, WHITE, 0.92),
        (lambda x, y: seg_dist(x, y, 0.495, row2, 0.690, row2) - 0.038, WHITE, 0.72),
    ]


def render(size):
    px = 1.0 / size
    rows = []
    sh = shapes()
    for j in range(size):
        y = (j + 0.5) * px
        row = bytearray([0])  # PNG filter: none
        for i in range(size):
            x = (i + 0.5) * px
            r, g, b = BLUE
            for sdf, col, alpha in sh:
                cover = max(0.0, min(1.0, 0.5 - sdf(x, y) / px)) * alpha  # anti-aliased edge
                if cover:
                    r += (col[0] - r) * cover
                    g += (col[1] - g) * cover
                    b += (col[2] - b) * cover
            row += bytes((round(r), round(g), round(b)))
        rows.append(bytes(row))
    return b"".join(rows)


def png(size, raw):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)  # 8-bit RGB
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


if __name__ == "__main__":
    os.makedirs("icons", exist_ok=True)
    for name, size in [("icon-512.png", 512), ("icon-192.png", 192), ("apple-touch-icon.png", 180), ("icon-32.png", 32)]:
        with open(os.path.join("icons", name), "wb") as f:
            f.write(png(size, render(size)))
        print("wrote icons/" + name)
