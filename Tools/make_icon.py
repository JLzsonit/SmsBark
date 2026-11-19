# -*- coding: utf-8 -*-
"""
SmsBark 应用图标 —— 「双泡转发 · 液态玻璃」

设计语言（对应 iOS 26/27 / Apple 自家图标）：
  · 单一母题、大符号、几何极简
  · 鲜艳渐变底（系统蓝 → 系统紫），带柔和光斑，无描边无杂点
  · 前层实心白气泡（带尾巴，读得出是消息），后层半透明玻璃气泡（读得出是「另一台」）
  · 上缘聚光、下缘投影；层次靠明暗，不靠描边

输出三套外观（iOS 18+ 的 light / dark / tinted）：
  icon-1024.png / icon-1024-dark.png / icon-1024-tinted.png

用法（仓库根目录）：
    python Tools/make_icon.py [输出目录]
默认直接写入 Resources/Assets.xcassets/AppIcon.appiconset。
"""
import os
import sys
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

BASE = 1024
SS = 2                              # 超采样倍数（先大后缩，边缘才干净）
N = BASE * SS
OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else \
    "Resources/Assets.xcassets/AppIcon.appiconset"

# ── 几何（1024 基准）──────────────────────────────────────────────────
BACK_RECT = (436.0, 238.0, 866.0, 476.0)     # 后层玻璃气泡：右上偏移
BACK_R = 76.0
FRONT_RECT = (170.0, 414.0, 726.0, 734.0)    # 前层白气泡：左下压阵
FRONT_R = 92.0
# 前层气泡的尾巴：两段二次贝塞尔，起笔在左边框直段、收笔在下边框
FRONT_TAIL = ((170.0, 632.0), (160.0, 756.0), (206.0, 802.0),
              (270.0, 776.0), (318.0, 734.0))

TINT_BACK_ALPHA = 0.52      # 着色版里后泡的透明度，保住层次


def K(v):
    return v * SS


def bez2(p0, p1, p2, n=28):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1.0 - t
        pts.append((u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
                    u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]))
    return pts


def bubble_mask(rect, radius, tail=None):
    """对话气泡掩膜：圆角矩形 + 可选贝塞尔尾巴（PIL 直接并集，不会被腐蚀）。"""
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([K(rect[0]), K(rect[1]), K(rect[2]), K(rect[3])],
                        radius=K(radius), fill=255)
    if tail:
        S, C1, T, C2, E = tail
        poly = bez2(S, C1, T)[:-1] + bez2(T, C2, E)
        d.polygon([(K(x), K(y)) for x, y in poly], fill=255)
    return m


def back_mask():
    return bubble_mask(BACK_RECT, BACK_R)


def front_mask():
    return bubble_mask(FRONT_RECT, FRONT_R, FRONT_TAIL)


def edge_bands(mask):
    """内缘带 / 外缘带，均为 0-1 ndarray（形态学腐蚀做差，比 SDF 稳）。"""
    a = np.asarray(mask, dtype=np.float32) / 255.0
    din = np.asarray(mask.filter(ImageFilter.MinFilter(9)),
                     dtype=np.float32) / 255.0
    dout = np.asarray(mask.filter(ImageFilter.MaxFilter(9)),
                      dtype=np.float32) / 255.0
    return (np.clip(a - din, 0.0, 1.0),
            np.clip(dout - a, 0.0, 1.0),
            a)


def top_fade(y_edge):
    """以某条水平线为界，上亮下暗的权重（光照来自上方）。"""
    yy = np.linspace(0.0, 1.0, N, dtype=np.float32)[:, None]
    return np.clip((y_edge * SS - yy * N) / (20.0 * SS), 0.0, 1.0)


def make_bg(mode):
    """鲜艳渐变底 + 柔和光斑，返回 float ndarray (N,N,3)。"""
    if mode == "dark":
        c0 = np.array([22.0, 34.0, 88.0], dtype=np.float32)
        c1 = np.array([64.0, 26.0, 120.0], dtype=np.float32)
        blobs = [((0.18, 0.10), 0.55, (70, 110, 220), 0.30),
                 ((0.86, 0.90), 0.50, (120, 50, 200), 0.26)]
    else:
        c0 = np.array([10.0, 132.0, 255.0], dtype=np.float32)   # 系统蓝
        c1 = np.array([126.0, 78.0, 250.0], dtype=np.float32)   # 系统紫
        blobs = [((0.16, 0.08), 0.58, (170, 220, 255), 0.30),
                 ((0.88, 0.92), 0.52, (150, 70, 235), 0.24),
                 ((0.82, 0.30), 0.34, (255, 120, 210), 0.12)]

    x = np.linspace(0.0, 1.0, N, dtype=np.float32)[None, :]
    y = np.linspace(0.0, 1.0, N, dtype=np.float32)[:, None]
    t = np.clip(0.52 * x + 0.62 * y, 0.0, 1.0)[..., None]
    img = c0[None, None, :] * (1 - t) + c1[None, None, :] * t

    for (cx, cy), rad, col, amp in blobs:
        d = np.hypot(x - cx, y - cy) / rad
        w = (np.clip(1.0 - d, 0.0, 1.0) ** 2.0 * amp)[..., None]
        img = img * (1 - w) + np.array(col, dtype=np.float32)[None, None, :] * w
    return img


def np2img(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def img2np(im):
    return np.asarray(im.convert("RGB"), dtype=np.float32)


def add_shadow(bg_arr, mask, blur=22, dy=14, alpha=0.22, color=(6, 14, 60)):
    """符号的柔影：让气泡「浮」在背景上，而不是贴上去的贴纸。"""
    a = np.asarray(mask, dtype=np.float32) / 255.0 * alpha * 255
    sh = Image.new("RGBA", (N, N), color + (0,))
    sh.putalpha(Image.fromarray(a.astype(np.uint8), "L"))
    sh = sh.filter(ImageFilter.GaussianBlur(blur * SS / 2))
    sh = ImageChops.offset(sh, 0, int(dy * SS))
    sa = np.asarray(sh, dtype=np.float32)[..., 3:4] / 255.0
    return bg_arr * (1 - sa) + img2np(sh) * sa


def render(mode):
    """定稿：后层玻璃气泡 + 前层实心白气泡。"""
    bg = make_bg(mode)
    mb, mf = back_mask(), front_mask()
    ba = (np.asarray(mb, np.float32) / 255)[..., None]
    fa = (np.asarray(mf, np.float32) / 255)[..., None]

    # ── 后层：玻璃，比背景亮一点，只留上缘聚光 ──
    if mode == "dark":
        face_b = bg * 0.62 + 255.0 * 0.30
    else:
        face_b = bg * 0.64 + 255.0 * 0.36
    face_b = np.clip(face_b, 0.0, 255.0)
    rim_b = (edge_bands(mb)[0] * (np.asarray(mb, np.float32) / 255))[..., None]
    bg = bg * (1 - ba * 0.70) + face_b * (ba * 0.70)
    bg = bg + rim_b * top_fade((BACK_RECT[1] + BACK_RECT[3]) * 0.5) \
        * np.array([250.0, 252.0, 255.0], dtype=np.float32)[None, None, :] * 0.62

    # ── 前层投影落在后层上，层次才出来 ──
    bg = add_shadow(bg, mf)

    # ── 前层：实心白，底部一点点冷调，免得像一张纸 ──
    yy = np.linspace(0.0, 1.0, N, dtype=np.float32)[:, None, None]
    face = (np.ones((N, N, 3), dtype=np.float32)
            * np.array([253.0, 254.0, 255.0], dtype=np.float32)[None, None, :])
    face = face * (1.0 - 0.045 * yy)

    out = bg * (1 - fa) + face * fa
    out = out * (1 - (edge_bands(mf)[1] * 0.10)[..., None])
    return out


def tinted_image():
    """着色外观：透明底 + 白图形，后泡半透明以保留层次。"""
    back = back_mask().resize((BASE, BASE), Image.LANCZOS)
    back = back.point(lambda v: int(v * TINT_BACK_ALPHA))
    front = front_mask().resize((BASE, BASE), Image.LANCZOS)
    alpha = ImageChops.lighter(back, front)
    out = Image.new("RGBA", (BASE, BASE), (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def squircle(im, size, ratio=0.2237):
    """按 iOS 主屏圆角比裁切，用于预览。"""
    im = im.convert("RGBA").resize((size, size), Image.LANCZOS)
    m = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1],
                                        radius=int(size * 4 * ratio), fill=255)
    m = m.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(im, (0, 0), m)
    return out


def tinted_preview(im, tint=(10, 132, 255), size=280):
    """模拟系统给着色图标上色的效果（仅用于预览图）。"""
    im = im.convert("RGBA").resize((size, size), Image.LANCZOS)
    solid = Image.new("RGBA", (size, size), tint + (255,))
    solid.putalpha(im.split()[3])
    tile = Image.new("RGBA", (size, size), (28, 28, 30, 255))
    tile.alpha_composite(solid)
    return tile


def make_sheet(light, dark, tinted, path):
    W, H = 1240, 660
    c = Image.new("RGB", (W, H), (242, 242, 247))
    d = ImageDraw.Draw(c)
    f = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 21)
    fs = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 17)
    d.text((80, 20), "SmsBark · 应用图标 · 双泡转发 · iOS 26/27 液态玻璃",
           fill=(110, 110, 118), font=fs)

    items = [(light, "浅色", False), (dark, "深色", False),
             (tinted, "着色（模拟）", True)]
    x = 70
    for im, label, is_tint in items:
        if is_tint:
            big = squircle(tinted_preview(im, size=280), 280)
            tiny = squircle(tinted_preview(im, size=60), 60)
        else:
            big = squircle(im, 280)
            tiny = squircle(im, 60)
        c.paste(big, (x, 64), big)
        d.text((x + 140 - d.textlength(label, font=f) / 2, 358), label,
               fill=(48, 48, 54), font=f)
        c.paste(tiny, (x + 110, 406), tiny)
        x += 380
    d.text((80, 510), "上方 280px 展示 · 下方为 iPhone 主屏实际显示尺寸（60pt）",
           fill=(140, 140, 148), font=fs)
    c.save(path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    light = np2img(render("light")).resize((BASE, BASE), Image.LANCZOS)
    dark = np2img(render("dark")).resize((BASE, BASE), Image.LANCZOS)
    tinted = tinted_image()

    light.save(os.path.join(OUT_DIR, "icon-1024.png"))
    dark.save(os.path.join(OUT_DIR, "icon-1024-dark.png"))
    tinted.save(os.path.join(OUT_DIR, "icon-1024-tinted.png"))
    print("saved icon-1024.png / -dark.png / -tinted.png ->", OUT_DIR)

    # 预览图不放进 Assets（未在 Contents.json 里登记的图片会让构建报未分配资源）
    os.makedirs("dist", exist_ok=True)
    make_sheet(light, dark, tinted, os.path.join("dist", "icon-preview.png"))
    print("preview -> dist/icon-preview.png")


if __name__ == "__main__":
    main()
