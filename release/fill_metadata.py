#!/usr/bin/env python3
"""DuoFolio 四语元数据装填: name/subtitle/description/keywords/whatsNew → PREPARE_FOR_SUBMISSION."""
import sys, json, requests
sys.path.insert(0, "/Users/phinn/Library/Application Support/KinetASCWatch/tools")
from asc_api import make_token

TOK = make_token()
HJ = {"Authorization": "Bearer " + TOK, "Content-Type": "application/json"}
HG = {"Authorization": "Bearer " + TOK}
BASE = "https://api.appstoreconnect.apple.com/v1"
VER = "284afc59-5d2c-4cb6-813a-a51d1bc3cb6d"

M = {
"zh-Hans": {
 "name": "DuoFolio - 折叠屏对开阅读器",
 "subtitle": "双屏对开 · 合盖书签 · 纯本地",
 "desc": """DuoFolio 是为 iPhone Duo 而生的沉浸式阅读器:一屏一本,双屏对开。
真正为折叠形态设计的排版引擎——展开即双页书卷,合上即单页流式。

· 双屏对开:像翻开一本真正的书,左右页各自成页,中缝有纸感阴影
· 合盖书签:合上手机,外屏自动显示封面、书名与进度,翻开即续读
· 纯本地:你的 EPUB 只属于你,无账号、无上传、无追踪
· 精致排版:衬线字体、行距优化、纸张色主题,为长时间阅读而调
· 位置记忆:精确到列的阅读进度,跨形态(直板/半开/全展开)无缝恢复

导入你自己的 EPUB,开始阅读。""",
 "kw": "阅读器,epub,电子书,对开,双屏,书,reader,book,duo",
 "whatsNew": "首发版本:双屏对开排版、合盖外屏书签卡、纯本地 EPUB 阅读。",
},
"zh-Hant": {
 "name": "DuoFolio - 摺疊螢幕對開閱讀器",
 "subtitle": "雙螢幕對開 ·闔蓋書籤 · 純本機",
 "desc": """DuoFolio 是為 iPhone Duo 而生的沉浸式閱讀器:一屏一本,雙屏對開。
真正為摺疊形態設計的排版引擎——展開即雙頁書卷,闔上即單頁流式。

· 雙屏對開:像翻開一本真正的書,左右頁各自成頁,中縫有紙感陰影
· 闔蓋書籤:闔上手機,外螢幕自動顯示封面、書名與進度,翻開即續讀
· 純本機:你的 EPUB 只屬於你,無帳號、無上傳、無追蹤
· 精緻排版:襯線字體、行距最佳化、紙張色主題,為長時間閱讀而調
· 位置記憶:精確到欄的閱讀進度,跨形態(直板/半開/全展開)無縫恢復

匯入你自己的 EPUB,開始閱讀。""",
 "kw": "閱讀器,epub,電子書,對開,雙螢幕,書,reader,book,duo",
 "whatsNew": "首發版本:雙屏對開排版、闔蓋外螢幕書籤卡、純本機 EPUB 閱讀。",
},
"en-US": {
 "name": "DuoFolio - Foldable Spread Reader",
 "subtitle": "Two-page spread · Cover bookmark · Local-only",
 "desc": """DuoFolio is an immersive reader built for iPhone Duo: one book per screen, true two-page spreads.
A layout engine designed for the fold — unfold for a bound book, fold for a single flowing column.

· Two-page spread: reads like a real book, separate left/right pages with a paper-feel gutter
· Cover bookmark: close the phone and the outer display shows cover, title & progress — flip open to continue
· Local-only: your EPUBs stay yours. No account, no upload, no tracking
· Refined typography: serif faces, tuned line spacing, paper-tone themes for long sessions
· Position memory: column-accurate progress that follows you across folded, half-open and fully open

Import your own EPUB and start reading.""",
 "kw": "reader,epub,book,spread,foldable,duo,ebook,reading",
 "whatsNew": "Initial release: two-page spread layout, cover bookmark on the outer display, local-only EPUB reading.",
},
"ja": {
 "name": "DuoFolio - 折りたたみ見開きリーダー",
 "subtitle": "見開き表示 · カバーしおり · ローカル完結",
 "desc": """DuoFolio は iPhone Duo のために生まれた没入型リーダー:1画面 1 冊、両画面で見開き。
折りたたみ形态のために設計された組版エンジン——広げれば見開きの書物、閉じれば 1 カラムの流し読み。

· 見開き表示:本を広げるように左右が独立ページ、中央の溝に紙のような影
· カバーしおり:閉じると外画面に表紙・タイトル・進捗を表示、開けば続きから
· ローカル完結:あなたの EPUB はあなたのもの。アカウント不要、アップロードなし、追跡なし
· 洗練された組版:セリフ書体、行間調整、紙色のテーマで長時間の読書に対応
· 位置記憶:カラム単位の読書位置を、直板/半開き/全展開の各形态でシームレスに復元

自分の EPUB を読み込んで、読書を始めましょう。""",
 "kw": "リーダー,epub,電子書籍,見開き,リーディング,本,duo,book",
 "whatsNew": "初回リリース:見開き組版、外画面のカバーしおり、ローカル完結 EPUB リーディング。",
},
}

locs = requests.get(f"{BASE}/appStoreVersions/{VER}/appStoreVersionLocalizations", headers=HG, timeout=30).json()["data"]
LIDS = {x["attributes"]["locale"]: x["id"] for x in locs}
print("locales:", list(LIDS))

for loc, m in M.items():
    lid = LIDS.get(loc)
    if not lid:
        print(f"[{loc}] missing lid, skip"); continue
    # 1) name/subtitle 在 appInfoLocalizations 层
    info = requests.get(f"{BASE}/appStoreVersions/{VER}/relationships/appInfo", headers=HG, timeout=30).json()["data"]["id"]
    ails = requests.get(f"{BASE}/appInfos/{info}/appInfoLocalizations", headers=HG, timeout=30).json()["data"]
    ail = next((x for x in ails if x["attributes"]["locale"] == loc), None)
    if ail:
        b = {"data": {"type": "appInfoLocalizations", "id": ail["id"],
             "attributes": {"name": m["name"], "subtitle": m["subtitle"]}}}
        r = requests.patch(f"{BASE}/appInfoLocalizations/{ail['id']}", headers=HJ, data=json.dumps(b), timeout=30)
        print(f"[{loc}] name/subtitle:", r.status_code)
    # 2) desc/keywords/whatsNew 在 version localization 层
    b = {"data": {"type": "appStoreVersionLocalizations", "id": lid,
         "attributes": {"description": m["desc"], "keywords": m["kw"], "whatsNew": m["whatsNew"]}}}
    r = requests.patch(f"{BASE}/appStoreVersionLocalizations/{lid}", headers=HJ, data=json.dumps(b), timeout=30)
    print(f"[{loc}] desc/kw/whatsNew:", r.status_code, "" if r.status_code < 300 else r.text[:150])
