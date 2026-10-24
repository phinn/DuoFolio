#!/usr/bin/env python3
"""DuoFolio 首图/次图重设计 v3 —— 大标题、大主体、单一主张、特性胶囊
6.7 1290×2796(成品 886×1920 放大 1.456)/ iPad 2048×2732 / Duo 2007×2853
设计原则(对照 v2 丑点):
- 品牌字号 ↑(v2 113px 太弱 → 150px)
- 书帧占屏 ↑(v2 16% → 36%+)
- 文案收敛:一主一辅,不堆四段
- 特性改胶囊横排,贴底部
"""
import os
from PIL import Image, ImageDraw, ImageFont

S = "/Users/phinn/Documents/kinet/DuoFolio/release/screenshots"
OUT = f"{S}/i18n"
PAPER = (250, 244, 232)
INK = (74, 62, 48)
ACCENT = (178, 118, 62)
SOFT = (130, 112, 94)
CARD = (243, 234, 216)

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

def fit_h(im, h):
    return im.resize((int(im.width * h / im.height), h), Image.LANCZOS)

def fit_w(im, w):
    return im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)

def capsule(d, cx, cy, text, lang, pad=28, fs=30, fill=CARD, fg=INK):
    f = font(lang, fs)
    tw = d.textlength(text, font=f)
    th = int(fs * 1.15)
    x0, y0 = cx - tw/2 - pad, cy - th/2 - pad//2
    x1, y1 = cx + tw/2 + pad, cy + th/2 + pad//2
    d.rounded_rectangle([x0, y0, x1, y1], radius=(y1-y0)//2, fill=fill)
    # 文字垂直居中:ascent 修正
    bbox = d.textbbox((0,0), text, font=f)
    d.text((cx - tw/2, cy - (bbox[3]-bbox[1])/2 - bbox[1]), text, font=f, fill=fg)

COPY = {
    "en": dict(
        sub="A spread reader made for iPhone Duo",
        main_head="Reads like a real book.",
        main_sub="Two-page spread on one screen.",
        pills=["Cover bookmark", "Pure local", "384-page EPUB"],
        lap_head="Flip it. Keep reading.",
        lap_sub="The cover screen holds your place.",
        feat=["384 pages  |  full EPUB", "Two-page spread", "0 network  |  fully offline"],
    ),
    "zh-Hans": dict(
        sub="为 iPhone Duo 而生的对开阅读器",
        main_head="像真书一样读。",
        main_sub="一屏对开双页,中缝有纸感。",
        pills=["合盖书签", "纯本地", "384 页全本"],
        lap_head="合上,接着读。",
        lap_sub="外屏替你记住进度。",
        feat=["384 页  |  全本 EPUB", "对开双页翻阅", "0 网络  |  纯本地"],
    ),
    "zh-Hant": dict(
        sub="為 iPhone Duo 而生的對開閱讀器",
        main_head="像真書一樣讀。",
        main_sub="一螢幕對開雙頁,中縫有紙感。",
        pills=["闔蓋書籤", "純本機", "384 頁全本"],
        lap_head="闔上,接著讀。",
        lap_sub="外螢幕替你記住進度。",
        feat=["384 頁  |  全本 EPUB", "對開雙頁翻閱", "0 網路  |  純本機"],
    ),
    "ja": dict(
        sub="iPhone Duo のために生まれた見開きリーダー",
        main_head="本のように読める。",
        main_sub="1画面に見開き2ページ、中央に紙の溝。",
        pills=["カバーしおり", "ローカル完結", "384ページ収録"],
        lap_head="閉じても、続きから。",
        lap_sub="外画面が進捗を覚えている。",
        feat=["384 ページ  |  完全版 EPUB", "見開き 2 ページ表示", "0 通信  |  完全オフライン"],
    ),
}

# ── 6.7 #1 main:大标题 + 大书帧 + 一句主张 + 胶囊 ──
def make_67_main(lang, c):
    W, H = 886, 1920
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 14], fill=ACCENT)
    # 品牌
    text_c(d, (W/2, 100), "DuoFolio", font(lang, 120, True), INK)
    text_c(d, (W/2, 260), c["sub"], font(lang, 38), SOFT)
    # 书帧(大)
    fr = fit_w(Image.open("/tmp/df_frame_main.png"), int(W * 0.88))
    img.paste(fr, ((W - fr.width)//2, 400))
    y = 400 + fr.height + 90
    # 主张
    text_c(d, (W/2, y), c["main_head"], font(lang, 62, True), INK)
    text_c(d, (W/2, y + 105), c["main_sub"], font(lang, 40), SOFT)
    # 胶囊横排
    total_w = sum(d.textlength(t, font=font(lang, 28)) + 70 for t in c["pills"]) 
    total_w -= 40  # 末尾 pad 修正
    cx = (W - total_w)/2
    cy = y + 240
    for t in c["pills"]:
        f = font(lang, 28)
        tw = d.textlength(t, font=f)
        capsule(d, cx + tw/2 + 35, cy, t, lang, fs=28)
        cx += tw + 70
    return img

# ── 6.7 #2 laptop:场景式 —— 合盖/翻开行为 ──
def make_67_laptop(lang, c):
    W, H = 886, 1920
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 14], fill=ACCENT)
    text_c(d, (W/2, 90), c["lap_head"], font(lang, 66, True), INK)
    text_c(d, (W/2, 210), c["lap_sub"], font(lang, 40), SOFT)
    fr = fit_w(Image.open("/tmp/df_frame_laptop.png"), int(W * 0.90))
    img.paste(fr, ((W - fr.width)//2, 380))
    y = 380 + fr.height + 90
    text_c(d, (W/2, y), c["main_head"] if lang != "ja" else "開けば、見開きに。", font(lang, 54, True), INK)
    text_c(d, (W/2, y + 90), c["main_sub"] if lang != "ja" else "左右のページがずれない。", font(lang, 36), SOFT)
    # 胶囊
    pills = c["pills"]
    total_w = sum(d.textlength(t, font=font(lang, 28)) + 70 for t in pills) - 40
    cx = (W - total_w)/2
    cy = y + 220
    for t in pills:
        f = font(lang, 28)
        tw = d.textlength(t, font=f)
        capsule(d, cx + tw/2 + 35, cy, t, lang, fs=28)
        cx += tw + 70
    return img

# ── iPad:横版大帧 + 特性三行 ──
def make_ipad(lang, c):
    W, H = 2048, 2732
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 20], fill=ACCENT)
    text_c(d, (W/2, 130), "DuoFolio", font(lang, 190, True), INK)
    text_c(d, (W/2, 400), c["sub"], font(lang, 60), SOFT)
    fr = fit_w(Image.open("/tmp/df_frame_ipad.png"), int(W * 0.82))
    img.paste(fr, ((W - fr.width)//2, 620))
    y = 620 + fr.height + 100
    text_c(d, (W/2, y), c["main_head"], font(lang, 84, True), INK)
    text_c(d, (W/2, y + 140), c["main_sub"], font(lang, 54), SOFT)
    y2 = y + 300
    for i, feat in enumerate(c["feat"]):
        text_c(d, (W/2, y2 + i*95), feat, font(lang, 48), SOFT)
    return img

# ── Duo:双屏大图 + 两行 ──
def make_duo(lang, c):
    W, H = 2007, 2853
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 18], fill=ACCENT)
    text_c(d, (W/2, 120), "DuoFolio", font(lang, 165, True), INK)
    text_c(d, (W/2, 370), c["duo_sub"] if "duo_sub" in c else c["sub"], font(lang, 52), SOFT)
    L = fit_h(Image.open("/tmp/df_duo_left.png"), 1500)
    R = fit_h(Image.open("/tmp/df_duo_right.png"), 1500)
    gap = 70
    total = L.width + gap + R.width
    if total > W - 100:
        k = (W - 100) / total
        L = L.resize((int(L.width*k), 1500), Image.LANCZOS)
        R = R.resize((int(R.width*k), 1500), Image.LANCZOS)
        total = L.width + gap + R.width
    x0 = (W - total)//2
    img.paste(L, (x0, 620))
    img.paste(R, (x0 + L.width + gap, 620))
    y = 620 + 1500 + 100
    text_c(d, (W/2, y), c["lap_head"], font(lang, 92, True), INK)
    text_c(d, (W/2, y + 150), c["lap_sub"], font(lang, 58), SOFT)
    y2 = y + 330
    for i, feat in enumerate(c["feat"]):
        text_c(d, (W/2, y2 + i*100), feat, font(lang, 52), SOFT)
    return img

GEN = [("67_main", make_67_main, 1290, 2796),
       ("67_laptop", make_67_laptop, 1290, 2796),
       ("ipad", make_ipad, 2048, 2732),
       ("duo", make_duo, 2007, 2853)]

for lang, c in COPY.items():
    os.makedirs(f"{OUT}/v3/{lang}", exist_ok=True)
    for slot, fn, w, h in GEN:
        img = fn(lang, c)
        big = img.resize((w, h), Image.LANCZOS)
        p = f"{OUT}/v3/{lang}/{slot}.png"
        big.save(p)
        print(p, big.size, f"{os.path.getsize(p)//1024}KB")
