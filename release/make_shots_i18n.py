#!/usr/bin/env python3
"""DuoFolio ASC 截图四语生成器 v2(2026-10-25)
修复:US/ja 露出中文营销文案的根因 —— 四语共用一套中文图。
产出:release/screenshots/i18n/{lang}/{slot}.png
  6.7 槽 1290×2796 (main/laptop 两张,886×1920 成品放大)
  iPad13 槽 2048×2732
  Duo 槽 2007×2853
文案:en 独立;zh-Hans/zh-Hant/ja 各自翻译(共用版式)。
书帧素材:从已过审成品图裁出(/tmp/df_*.png),保证与真机截图同源。
"""
import os
from PIL import Image, ImageDraw, ImageFont

S = "/Users/phinn/Documents/kinet/DuoFolio/release/screenshots"
OUT = f"{S}/i18n"
PAPER = (250, 244, 232)
INK = (74, 62, 48)
ACCENT = (178, 118, 62)
SOFT = (130, 112, 94)

F_CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"
F_EN = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
F_EN_R = "/System/Library/Fonts/Supplemental/Georgia.ttf"
F_JA = "/System/Library/Fonts/Hiragino Sans GB.ttc"

def font(lang, size, bold=False):
    if lang.startswith("zh"):
        return ImageFont.truetype(F_CN, size, index=1 if bold else 0)
    if lang == "ja":
        return ImageFont.truetype(F_JA, size, index=1 if bold else 0)
    return ImageFont.truetype(F_EN if bold else F_EN_R, size)

def text_c(d, xy, s, f, fill=INK):
    w = d.textlength(s, font=f)
    d.text((xy[0] - w / 2, xy[1]), s, font=f, fill=fill)

def fit_h(im, h):
    w = int(im.width * h / im.height)
    return im.resize((w, h), Image.LANCZOS)

# ── 四语文案 ──
COPY = {
    "en": dict(
        sub="A spread reader made for iPhone Duo",
        f_main=[("Two-page spread", "Reads like a real book"),
                ("Tap the spine to jump", "Open at your page")],
        f_lap=[("Flip on the cover screen", "Cover & progress, always visible"),
               ("Unfold into a spread", "Left/right pages stay aligned")],
        ipad_head="DuoFolio",
        ipad_sub="Reads like a real book on iPhone Duo",
        ipad_feat=["384 pages · full EPUB", "Two-page spread", "0 network · fully offline"],
        duo_head="DuoFolio",
        duo_sub="One book across two screens",
        duo_feat=[("Flip on the cover screen", "Cover & progress on the outside"),
                  ("Unfold into a spread", "Pages stay left/right aligned")],
    ),
    "zh-Hans": dict(
        sub="为 iPhone Duo 而生的对开阅读器",
        f_main=[("双屏对开", "像真书一样翻页"),
                ("合盖秒变书签卡", "翻盖即续读")],
        f_lap=[("外屏翻页,不惊动正文", "合盖外屏亮出封面与进度"),
               ("展开即对开", "左右页奇偶对齐")],
        ipad_head="DuoFolio",
        ipad_sub="为 iPhone Duo 而生的对开阅读器",
        ipad_feat=["384 页 · 全本 epub", "对开双页翻阅", "0 网络 · 纯本地"],
        duo_head="DuoFolio",
        duo_sub="一本书,跨两块屏",
        duo_feat=[("外屏翻页,不惊动正文", "合盖外屏亮出封面与进度"),
                  ("展开即对开", "左右页奇偶对齐")],
    ),
    "zh-Hant": dict(
        sub="為 iPhone Duo 而生的對開閱讀器",
        f_main=[("雙屏對開", "像真書一樣翻頁"),
                ("闔蓋秒變書籤卡", "翻蓋即續讀")],
        f_lap=[("外屏翻頁,不驚動內文", "闔蓋外屏亮出封面與進度"),
               ("展開即對開", "左右頁奇偶對齊")],
        ipad_head="DuoFolio",
        ipad_sub="為 iPhone Duo 而生的對開閱讀器",
        ipad_feat=["384 頁 · 全本 epub", "對開雙頁翻閱", "0 網路 · 純本機"],
        duo_head="DuoFolio",
        duo_sub="一本書,跨兩塊螢幕",
        duo_feat=[("外屏翻頁,不驚動內文", "闔蓋外屏亮出封面與進度"),
                  ("展開即對開", "左右頁奇偶對齊")],
    ),
    "ja": dict(
        sub="iPhone Duo のために生まれた見開きリーダー",
        f_main=[(" dual 2画面見開き", "本のようにめくる"),
                ("閉じればしおりに", "開ければ続きから")],
        f_lap=[("表画面でめくる、本体はそのまま", "閉じても表紙と進度を表示"),
               ("開けば見開きに", "左右のページを揃えて表示")],
        ipad_head="DuoFolio",
        ipad_sub="iPhone Duo のために生まれた見開きリーダー",
        ipad_feat=["384 ページ · 完全版 epub", "見開き 2 ページ表示", "0 通信 · 完全オフライン"],
        duo_head="DuoFolio",
        duo_sub="一冊の本が、2 つの画面へ",
        duo_feat=[("表画面でめくる、本体はそのまま", "閉じても表紙と進度を表示"),
                  ("開けば見開きに", "左右のページを揃えて表示")],
    ),
}
# ja 首条笔误修正
COPY["ja"]["f_main"][0] = ("2画面見開き", "本のようにめくる")

def footer_rows(d, y, W, rows, lang, f1s, f2s, spacing=150):
    f1 = font(lang, f1s, True); f2 = font(lang, f2s)
    for t, s in rows:
        text_c(d, (W / 2, y), t, f1, INK)
        text_c(d, (W / 2, y + int(f1s * 1.45)), s, f2, SOFT)
        y += spacing

# ── 6.7 成品 886×1920:main ──
def make_67_main(lang, c):
    W, H = 886, 1920
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 10], fill=ACCENT)
    text_c(d, (W / 2, 96), "DuoFolio", font(lang, 100, True), INK)
    text_c(d, (W / 2, 226), c["sub"], font(lang, 40), SOFT)
    fr = fit_h(Image.open("/tmp/df_frame_main.png"), 800)
    img.paste(fr, ((W - fr.width) // 2, 360))
    footer_rows(d, 1300, W, c["f_main"][0:1], lang, 46, 34, spacing=200)
    text_c(d, (W / 2, 1620), c["f_main"][1][0], font(lang, 46, True), INK)
    text_c(d, (W / 2, 1690), c["f_main"][1][1], font(lang, 34), SOFT)
    return img

# ── 6.7 成品 886×1920:laptop ──
def make_67_laptop(lang, c):
    W, H = 886, 1920
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 10], fill=ACCENT)
    text_c(d, (W / 2, 96), "DuoFolio", font(lang, 100, True), INK)
    text_c(d, (W / 2, 226), c["sub"], font(lang, 40), SOFT)
    fr = fit_h(Image.open("/tmp/df_frame_laptop.png"), 700)
    img.paste(fr, ((W - fr.width) // 2, 400))
    footer_rows(d, 1300, W, c["f_lap"][0:1], lang, 46, 34, spacing=200)
    text_c(d, (W / 2, 1620), c["f_lap"][1][0], font(lang, 46, True), INK)
    text_c(d, (W / 2, 1690), c["f_lap"][1][1], font(lang, 34), SOFT)
    return img

# ── iPad 13 槽 2048×2732 ──
def make_ipad(lang, c):
    W, H = 2048, 2732
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 16], fill=ACCENT)
    text_c(d, (W / 2, 120), c["ipad_head"], font(lang, 170, True), INK)
    text_c(d, (W / 2, 340), c["ipad_sub"], font(lang, 62), SOFT)
    fr = fit_h(Image.open("/tmp/df_frame_ipad.png"), 880)
    img.paste(fr, ((W - fr.width) // 2, 560))
    y = 1620
    for feat in c["ipad_feat"]:
        text_c(d, (W / 2, y), feat, font(lang, 58, True), INK)
        y += 120
    return img

# ── Duo 槽 2007×2853 ──
def make_duo(lang, c):
    W, H = 2007, 2853
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 16], fill=ACCENT)
    text_c(d, (W / 2, 110), c["duo_head"], font(lang, 150, True), INK)
    text_c(d, (W / 2, 300), c["duo_sub"], font(lang, 56), SOFT)
    L = Image.open("/tmp/df_duo_left.png")
    R = Image.open("/tmp/df_duo_right.png")
    ph = 1500
    L = fit_h(L, ph); R = fit_h(R, ph)
    gap = 60
    total = L.width + gap + R.width
    k = (W - 120) / total
    if k < 1:
        L = L.resize((int(L.width * k), ph), Image.LANCZOS)
        R = R.resize((int(R.width * k), ph), Image.LANCZOS)
    x0 = (W - (L.width + gap + R.width)) // 2
    img.paste(L, (x0, 520))
    img.paste(R, (x0 + L.width + gap, 520))
    y = 520 + ph + 90
    for t, s in c["duo_feat"]:
        text_c(d, (W / 2, y), t, font(lang, 54, True), INK)
        text_c(d, (W / 2, y + 80), s, font(lang, 40), SOFT)
        y += 200
    return img

GEN = [("67_main", make_67_main, 1290, 2796),
       ("67_laptop", make_67_laptop, 1290, 2796),
       ("ipad", make_ipad, 2048, 2732),
       ("duo", make_duo, 2007, 2853)]

for lang, c in COPY.items():
    os.makedirs(f"{OUT}/{lang}", exist_ok=True)
    for slot, fn, w, h in GEN:
        img = fn(lang, c)
        big = img.resize((w, h), Image.LANCZOS)
        p = f"{OUT}/{lang}/{slot}.png"
        big.save(p)
        print(p, big.size)
