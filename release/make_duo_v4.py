#!/usr/bin/env python3
"""Duo 槽 v4 —— 「一台 iPhone Duo 展开态」构图(SKILL §3.3 定义)
- 主体 = 一台横置设备(单一大设备框,深色边框),框内左右两页真书正文 + 中缝折痕带
- 四语文案(en/zh-Hans/zh-Hant/ja),en 全 ASCII
- 成品 2007×2853;设备帧内容源自模拟器真书对开截图(/tmp/df_page_left|right.png)
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = "/Users/phinn/Documents/kinet/DuoFolio/release/screenshots/i18n"
PAPER = (250, 244, 232)
INK = (74, 62, 48)
ACCENT = (178, 118, 62)
SOFT = (130, 112, 94)
CARD = (243, 234, 216)
FRAME = (44, 40, 36)          # 设备深色边框
FRAME_IN = (12, 12, 12)       # 屏幕 black bezel

F_CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"
F_EN = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
F_EN_R = "/System/Library/Fonts/Supplemental/Georgia.ttf"

def font(lang, size, bold=False):
    if lang.startswith("zh") or lang == "ja":
        return ImageFont.truetype(F_CN, size, index=1 if bold else 0)
    return ImageFont.truetype(F_EN if bold else F_EN_R, size)

def text_c(d, xy, s, f, fill=INK):
    w = d.textlength(s, font=f)
    d.text((xy[0] - w / 2, xy[1]), s, font=f, fill=fill)

COPY = {
    "en": dict(
        head="Reads like a real book.",
        sub="Unfold iPhone Duo — a true two-page spread.",
        cap_l="Left page",
        cap_r="Right page",
        feat=["384 pages  |  full EPUB", "Cover bookmark when closed", "0 network  |  fully offline"],
    ),
    "zh-Hans": dict(
        head="像真书一样读。",
        sub="展开 iPhone Duo,即得真书对开双页。",
        cap_l="左页",
        cap_r="右页",
        feat=["384 页  |  全本 EPUB", "合盖即成书签", "0 网络  |  纯本地"],
    ),
    "zh-Hant": dict(
        head="像真書一樣讀。",
        sub="展開 iPhone Duo,即得真書對開雙頁。",
        cap_l="左頁",
        cap_r="右頁",
        feat=["384 頁  |  全本 EPUB", "闔蓋即成書籤", "0 網路  |  純本機"],
    ),
    "ja": dict(
        head="本のように読める。",
        sub="iPhone Duo を広げれば、見開き 2 ページ。",
        cap_l="左ページ",
        cap_r="右ページ",
        feat=["384 ページ  |  完全版 EPUB", "閉じればしおりに", "0 通信  |  完全オフライン"],
    ),
}

def fit_h(im, h):
    return im.resize((int(im.width * h / im.height), h), Image.LANCZOS)

def make_duo(lang, c):
    W, H = 2007, 2853
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 18], fill=ACCENT)
    # 品牌 + 主张
    text_c(d, (W/2, 90), "DuoFolio", font(lang, 150, True), INK)
    text_c(d, (W/2, 300), c["head"], font(lang, 78, True), INK)
    text_c(d, (W/2, 440), c["sub"], font(lang, 52), SOFT)

    # ── 一台展开态设备:单一大框,内含左右两页 ──
    PAGE_H = 1450
    L = fit_h(Image.open("/tmp/df_page_left.png"), PAGE_H)
    R = fit_h(Image.open("/tmp/df_page_right.png"), PAGE_H)
    crease = 26                      # 中缝折痕带
    screen_w = L.width + crease + R.width
    bezel = 26                       # 屏幕 black bezel
    border = 22                      # 深色机身边框
    dev_w = screen_w + bezel*2 + border*2
    if dev_w > W - 90:
        k = (W - 90) / dev_w
        PAGE_H = int(PAGE_H * k)
        L = fit_h(Image.open("/tmp/df_page_left.png"), PAGE_H)
        R = fit_h(Image.open("/tmp/df_page_right.png"), PAGE_H)
        screen_w = L.width + crease + R.width
        dev_w = screen_w + bezel*2 + border*2
    dev_h = PAGE_H + bezel*2 + border*2
    dx = (W - dev_w) // 2
    dy = 640

    # 机身边框(圆角) + 黑 bezel
    d.rounded_rectangle([dx, dy, dx+dev_w, dy+dev_h], 64, fill=FRAME)
    sx0, sy0 = dx+border, dy+border
    d.rounded_rectangle([sx0, sy0, sx0+screen_w+bezel*2, sy0+PAGE_H+bezel*2], 40, fill=FRAME_IN)
    # 左右页 + 中缝折痕
    px0, py0 = sx0+bezel, sy0+bezel
    img.paste(L, (px0, py0))
    img.paste(R, (px0 + L.width + crease, py0))
    d = ImageDraw.Draw(img)
    cxm = px0 + L.width + crease//2
    for yy in range(py0, py0+PAGE_H, 16):
        d.line([(cxm, yy), (cxm, yy+8)], fill=(168, 150, 126), width=3)
    # 屏幕内高光(顶部细白线,质感)
    d.rounded_rectangle([sx0+bezel, py0, sx0+bezel+screen_w, py0+8], 4, fill=(255,255,255))

    # 页标签(设备框下方,左右对齐各自页)
    capy = dy + dev_h + 46
    fcap = font(lang, 44)
    lw = d.textlength(c["cap_l"], font=fcap); rw = d.textlength(c["cap_r"], font=fcap)
    d.text((px0 + L.width/2 - lw/2, capy), c["cap_l"], font=fcap, fill=SOFT)
    d.text((px0 + L.width + crease + R.width/2 - rw/2, capy), c["cap_r"], font=fcap, fill=SOFT)

    # 特性三行
    y = capy + 130
    for i, feat in enumerate(c["feat"]):
        text_c(d, (W/2, y + i*104), feat, font(lang, 54), SOFT)
    return img

for lang, c in COPY.items():
    os.makedirs(f"{OUT}/v4/{lang}", exist_ok=True)
    img = make_duo(lang, c)
    img.save(f"{OUT}/v4/{lang}/duo.png")
    print(f"v4/{lang}/duo.png", img.size, os.path.getsize(f"{OUT}/v4/{lang}/duo.png"))
