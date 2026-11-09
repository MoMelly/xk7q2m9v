"""生成备用 App 图标（S-20）。

不引 Pillow：只画渐变底 + 一个圆角屏幕，用有符号距离场逐像素算就行。
跑一次把三套图标写进 Assets.xcassets，之后构建不用再跑。

用法：
    python scripts/make_alt_icons.py
"""

import math
import os
import struct
import zlib

SIZE = 1024
OUT_ROOT = os.path.join("MiniPhone", "Assets.xcassets")

# 名字 → (顶部色, 底部色, 屏幕上那块的颜色)
VARIANTS = {
    "AppIconCream": ((0.98, 0.97, 0.93), (0.92, 0.93, 0.88), (0.29, 0.47, 0.39)),
    "AppIconNight": ((0.10, 0.11, 0.13), (0.06, 0.07, 0.08), (0.62, 0.82, 0.71)),
    "AppIconForest": ((0.16, 0.32, 0.26), (0.07, 0.14, 0.12), (0.97, 0.96, 0.92)),
}


def rounded_rect_sdf(x, y, cx, cy, half_w, half_h, radius):
    """有符号距离：负值在形状内。"""
    dx = abs(x - cx) - (half_w - radius)
    dy = abs(y - cy) - (half_h - radius)
    outside = math.hypot(max(dx, 0.0), max(dy, 0.0))
    inside = min(max(dx, dy), 0.0)
    return outside + inside - radius


def blend(base, over, alpha):
    return tuple(base[i] * (1 - alpha) + over[i] * alpha for i in range(3))


def render(top, bottom, glyph):
    """返回 1024×1024 的 RGB 字节流。"""
    rows = []
    cx = cy = SIZE / 2.0
    # 屏幕外框
    hw, hh, radius = SIZE * 0.215, SIZE * 0.315, SIZE * 0.085
    stroke = SIZE * 0.026
    # 听筒那条横线
    bar_y = cy - hh * 0.62

    for y in range(SIZE):
        row = bytearray()
        t = y / (SIZE - 1)
        bg = tuple(top[i] * (1 - t) + bottom[i] * t for i in range(3))
        for x in range(SIZE):
            d = rounded_rect_sdf(x, y, cx, cy, hw, hh, radius)
            color = bg

            # 外框：距离在 [0, stroke] 之间上色，用 1px 软化抗锯齿
            edge = abs(d + stroke / 2.0) - stroke / 2.0
            alpha = 1.0 - min(1.0, max(0.0, edge + 0.5))
            if alpha > 0:
                color = blend(color, glyph, alpha * 0.92)

            # 屏幕里一块淡淡的底色，做出「亮着」的感觉
            if d < -stroke * 1.6:
                color = blend(color, glyph, 0.10)

            # 听筒
            if abs(y - bar_y) < stroke * 0.42 and abs(x - cx) < hw * 0.34:
                color = blend(color, glyph, 0.92)

            row += bytes(
                (
                    int(max(0.0, min(1.0, color[0])) * 255),
                    int(max(0.0, min(1.0, color[1])) * 255),
                    int(max(0.0, min(1.0, color[2])) * 255),
                )
            )
        rows.append(bytes(row))
    return rows


def write_png(path, rows):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as handle:
        handle.write(png)


def contents_json(name):
    return (
        '{\n'
        '  "images" : [\n'
        '    {\n'
        f'      "filename" : "{name}.png",\n'
        '      "idiom" : "universal",\n'
        '      "platform" : "ios",\n'
        '      "size" : "1024x1024"\n'
        '    }\n'
        '  ],\n'
        '  "info" : {\n'
        '    "author" : "xcode",\n'
        '    "version" : 1\n'
        '  }\n'
        '}\n'
    )


def main():
    for name, (top, bottom, glyph) in VARIANTS.items():
        folder = os.path.join(OUT_ROOT, f"{name}.appiconset")
        os.makedirs(folder, exist_ok=True)
        rows = render(top, bottom, glyph)
        write_png(os.path.join(folder, f"{name}.png"), rows)
        with open(os.path.join(folder, "Contents.json"), "w", encoding="utf-8") as handle:
            handle.write(contents_json(name))
        print("wrote", folder)


if __name__ == "__main__":
    main()
