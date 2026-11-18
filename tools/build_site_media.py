#!/usr/bin/env python3
"""为 DuoFolio 官网生成展示素材。

素材来源是模拟器真机截图(release/preview_1.0.5/shots/),裁掉系统状态浮层与
App 外框,再按站点纸感风格重新合成:对开双页 / 书库 / iPad / 合盖封面卡。
产物落在 site/docs/screenshots 与 site/docs/media。
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "docs")
SHOTS = "/Users/phinn/Documents/kinet/DuoFolio/release/preview_1.0.5/shots"
ART = "/Users/phinn/Documents/kinet/DuoFolio/release/screenshots"

PAPER = (250, 246, 238)
INK = (61, 47, 36)
CROP = (108, 470, 1322, 1736)          # 版心:去状态浮层/页眉/底部进度条

os.makedirs(f"{SITE}/screenshots", exist_ok=True)
os.makedirs(f"{SITE}/media/pages", exist_ok=True)


def erase_blob(im, box):
    """box 内是纯纸面,只有系统时间/wifi 浮层 → 用邻近纸色整块填平。"""
    a = np.asarray(im.convert("RGB")).copy()
    x0, y0, x1, y1 = box
    strip = a[y0:min(y1, a.shape[0]), max(0, x0 - 24):x0].reshape(-1, 3)
    fill = np.median(strip, axis=0).astype(np.uint8)
    a[y0:y1, x0:x1] = fill
    return Image.fromarray(a)


def fade_edges(im, top=74, bottom=74):
    """上下各做一段向纸色的渐隐,让裁切边读起来是页面延续而不是被切断。"""
    a = np.asarray(im).astype(np.float32)
    h = a.shape[0]
    for i in range(top):
        k = 1 - i / top
        a[i] = a[i] * (1 - k) + np.array(PAPER, dtype=np.float32) * k
    for i in range(bottom):
        k = 1 - i / bottom
        a[h - 1 - i] = a[h - 1 - i] * (1 - k) + np.array(PAPER, dtype=np.float32) * k
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def page(name):
    return fade_edges(Image.open(os.path.join(SHOTS, name)).convert("RGB").crop(CROP))


def spread(left_name, right_name, out_w=1600, gutter=26):
    """把左右两页拼成对开跨页,中缝加一道柔和纸缝阴影。"""
    l, r = page(left_name), page(right_name)
    ph, pw = l.height, l.width
    canvas = Image.new("RGB", (pw * 2 + gutter, ph), PAPER)
    canvas.paste(l, (0, 0))
    canvas.paste(r, (pw + gutter, 0))

    # 中缝:两侧各压一道渐变暗部,让两页读起来是贴在一个书脊上
    shade = Image.new("L", (canvas.width, 1), 0)
    px = shade.load()
    half = gutter // 2 + 30
    for x in range(pw - half, pw + gutter + half):
        d = abs(x - (pw + gutter / 2)) / (half + gutter / 2)
        px[x, 0] = int(64 * max(0.0, 1 - d) ** 1.7)
    shade = shade.resize((canvas.width, ph))
    canvas = Image.composite(Image.new("RGB", canvas.size, (58, 44, 32)), canvas, shade)
    return canvas.resize((out_w, int(canvas.height * out_w / canvas.width)), Image.LANCZOS)


def save(im, path, w, quality=84):
    h = int(im.height * w / im.width)
    im.resize((w, h), Image.LANCZOS).save(path, quality=quality, optimize=True, progressive=True)
    print(f"{path}  {w}x{h}  {os.path.getsize(path)//1024}KB")


# 1) 对开跨页(首屏 + 卷角演示底图)
sp = spread("page137.png", "page138.png")
save(sp, f"{SITE}/screenshots/spread.jpg", 1600)
sp2 = spread("page139.png", "page140.png")
save(sp2, f"{SITE}/screenshots/spread-2.jpg", 1600)

# 2) 书库:右上角状态浮层用纸色抹掉
lib = erase_blob(Image.open(os.path.join(SHOTS, "library.png")), (1170, 0, 1398, 560))
lib = lib.crop((0, 110, 1398, 1880))
save(lib, f"{SITE}/screenshots/library.jpg", 1020)

# 3) iPad 阅读页:去掉浮层,只留正文栏
ipd = erase_blob(Image.open(os.path.join(SHOTS, "ipad/read.png")), (1780, 0, 2048, 340))
ipd = ipd.crop((260, 170, 1800, 2560))
save(ipd, f"{SITE}/screenshots/ipad.jpg", 1240)

# 4) 合盖封面卡:只留机身,去掉营销文字(按深色边框自动找 bbox)
cov = Image.open(os.path.join(ART, "asc_duo_cover_en.png")).convert("RGB")
cov = cov.crop((392, 330, 1044, 1336))
save(cov, f"{SITE}/screenshots/cover.jpg", 460, 90)

# 5) 卷角演示用的单页纹理(左/右)
page("page137.png").resize((760, 823), Image.LANCZOS).save(
    f"{SITE}/media/pages/left.jpg", quality=86, optimize=True)
page("page138.png").resize((760, 823), Image.LANCZOS).save(
    f"{SITE}/media/pages/right.jpg", quality=86, optimize=True)
page("page139.png").resize((760, 823), Image.LANCZOS).save(
    f"{SITE}/media/pages/left2.jpg", quality=86, optimize=True)
page("page140.png").resize((760, 823), Image.LANCZOS).save(
    f"{SITE}/media/pages/right2.jpg", quality=86, optimize=True)
print("pages ok")
