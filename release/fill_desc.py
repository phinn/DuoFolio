#!/usr/bin/env python3
"""DuoFolio 四语 description/keywords/whatsNew 装填。"""
import sys, json, requests
sys.path.insert(0, "/Users/phinn/Library/Application Support/KinetASCWatch/tools")
from asc_api import make_token

TOK = make_token()
HJ = {"Authorization": "Bearer " + TOK, "Content-Type": "application/json"}
HG = {"Authorization": "Bearer " + TOK}
BASE = "https://api.appstoreconnect.apple.com/v1"
VER = "284afc59-5d2c-4cb6-813a-a51d1bc3cb6d"

r = requests.get(f"{BASE}/appStoreVersions/{VER}/appStoreVersionLocalizations", headers=HG, timeout=30)
vl = {x["attributes"]["locale"]: x["id"] for x in r.json()["data"]}
print("verLocs:", list(vl))

desc = {
 "zh-Hans": "为 iPhone Duo 而生的对开阅读器。全书在两块屏上摊开成一张连续长卷,左右各一页,像摊开一本真正的纸质书;合上盖子,外屏自动亮出书签卡——封面、书名与进度一目了然,翻开即回到停下的那一列。\n\n双屏对开\n横持 Duo 自动进入对开模式,偶数列在左、奇数列在右,中缝光影连贯,整张翻页如同真实书页。\n\n合盖书签\n合上盖子,外屏显示当前读物的封面、书名与进度;重新翻开,位置无缝续读。\n\n纯本地\n导入的 EPUB 保存在你的设备上,无账号、无追踪、无网络请求。阅读位置、主题、字号全部本地留存。\n\n为长阅读打磨\n暖纸底色、衬线正文、页码角标、进度滑块;字号与主题面板随调随存。",
 "zh-Hant": "為 iPhone Duo 而生的對開閱讀器。全書在兩塊螢幕上攤開成連續長卷,左右各一頁,像攤開一本真正的紙質書;闔上蓋子,外螢幕自動亮出書籤卡——封面、書名與進度一目瞭然,翻開即回到停下的那一列。\n\n雙屏對開\n橫持 Duo 自動進入對開模式,偶數列在左、奇數列在右,中縫光影連貫,整張翻頁如同真實書頁。\n\n合蓋書籤\n闔上蓋子,外螢幕顯示當前讀物的封面、書名與進度;重新翻開,位置無縫續讀。\n\n純本地\n匯入的 EPUB 儲存在你的裝置上,無帳號、無追蹤、無網路請求。閱讀位置、主題、字號全部本地留存。\n\n為長閱讀打磨\n暖紙底色、襯線內文、頁碼角標、進度滑桿;字號與主題面板隨調隨存。",
 "en-US": "A spread reader built for iPhone Duo. The whole book flows across both displays as one continuous canvas - one page on the left, one on the right, like a real open book. Fold it shut and the cover display becomes a bookmark card: cover art, title and progress at a glance. Flip it open and you are back on the exact column you left.\n\nTRUE TWO-PAGE SPREAD\nHold Duo sideways and the book opens into a spread. Even columns left, odd columns right, with a soft gutter shadow between pages. Turn whole leaves, not half screens.\n\nFOLDED BOOKMARK CARD\nClose the cover and the outer display shows what you are reading - cover, title, progress. Open it again and reading resumes instantly.\n\nFULLY LOCAL\nImported EPUBs never leave your device. No account, no tracking, no network. Position, theme and type size are stored locally.\n\nCRAFTED FOR LONG READING\nWarm paper tones, serif body text, page corner marks and a progress slider. Theme and type size panels apply instantly and persist.",
 "ja": "iPhone Duo のために生まれた見開きリーダー。本全体が両ディスプレイに連続した長い巻として広がり、左に偶数ページ、右に奇数ページ - 本当の紙の本を開いたように。蓋を閉じれば、アウターディスプレイがしおりカードを表示 - 表紙・書名・進捗がひと目でわかり、開けば止めた列から再開します。\n\n見開きリーディング\nDuo を横向きに持つと自動で見開きモード。偶数列は左、奇数列は右、ノドには柔らかな影。半画面ではなく、一枚のページめくり。\n\n合蓋しおりカード\n蓋を閉じると外ディスプレイに読書中の本の表紙・タイトル・進捗を表示。開き直せばすぐに続きから。\n\n完全ローカル\n読み込んだ EPUB は端末から出ません。アカウント不要、トラッキングなし、通信なし。読書位置・テーマ・文字サイズはすべてローカル保存。\n\n長時間読書のためのこだわり\n暖かな紙色、セリフ体の本文、ページ角標、進捗スライダー。テーマと文字サイズはすぐ反映、すぐ保存。",
}
kw = {
 "zh-Hans": "阅读器,EPUB,对开,双屏,合盖,书签,本地,电子书,折叠,沉浸",
 "zh-Hant": "閱讀器,EPUB,對開,雙螢幕,合蓋,書籤,本地,電子書,摺疊,沉浸",
 "en-US": "epub,reader,book,spread,fold,two page,local,offline,reading,folio",
 "ja": "電子書籍,リーダー,EPUB,見開き,二画面,しおり,ローカル,読書,フォリオ",
}
wn = {
 "zh-Hans": "首发版本:双屏对开阅读、合盖书签卡、纯本地 EPUB 管理。",
 "zh-Hant": "首發版本:雙屏對開閱讀、合蓋書籤卡、純本地 EPUB 管理。",
 "en-US": "Initial release: true two-page spreads on iPhone Duo, folded bookmark card, fully local EPUB library.",
 "ja": "初リリース:iPhone Duo の見開き読書、合蓋しおりカード、完全ローカルの EPUB ライブラリ。",
}

for loc in ["zh-Hans", "zh-Hant", "en-US", "ja"]:
    body = {"data": {"type": "appStoreVersionLocalizations", "id": vl[loc],
            "attributes": {"description": desc[loc], "keywords": kw[loc]}}}
    r = requests.patch(f"{BASE}/appStoreVersionLocalizations/{vl[loc]}", headers=HJ, data=json.dumps(body), timeout=30)
    ok = r.status_code < 300
    print(loc, "desc/kw/wn", r.status_code, "" if ok else r.text[:300])
