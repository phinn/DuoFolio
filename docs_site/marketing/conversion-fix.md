# DuoFolio · ASC 手贴工单:转化层修复(2026-11-13)

> 依据:上架 6 周漏斗(Impressions 5563 → PV 1330 → DL 6,PV→DL 0.45% vs 健康 25-35%)。
> 目标:把「每 220 个 PV 出 1 单」修到「每 4-5 个 PV 出 1 单」。
> 全部改动走 **1.0.4 READY_FOR_SALE 版本直接修改,免审核立即生效**;新 build 才触发审核。
> 版本 localization ID:en `08306323` / zh-Hans `95ec4a66` / zh-Hant `80b80405` / ja `31ab6d9a`

---

## 0. 结论先行(按杠杆排序)

| # | 动作 | 理由 | 生效方式 |
|---|---|---|---|
| 1 | en-US 补 subtitle(四语唯一空缺的黄金位) | 搜索结果第一行卖点,自筛受众 | API PATCH,免审 |
| 2 | promo text 四语全补(全空) | **免审随时改**,降价公告栏 | API PATCH,免审 |
| 3 | en keywords 补满(51→70 字符) | 免费搜索流量 | API PATCH,免审 |
| 4 | 6.7" 截图 2→2 替换为新版(四语 67_main/67_laptop 库存齐) | 类目浏览第一图自证「为折叠而生」 | API 上传,免审 |
| 5 | en 描述重写(受众过滤+劝退声明+藏书钩子) | PV→DL 崩盘主因:泛读者见 $6.99 直接走 | 手贴(四语文案全备) |
| 6 | 优惠价 intro($6.99→首两周 $2.99) | 价格自筛+冲首批评分 | 见 `price-drop-playbook.md` |

## A. subtitle 副标题(30 字符上限,四语全空)

写法逻辑:名字不用重复;先说给谁(折叠屏),再说形态(对开);**不放**「不上云/本地」这类支撑点。

| 语言 | 文案 | 字符数 |
|---|---|---|
| en-US | `Two-page reading on iPhone Duo` | 30 ✅ |
| zh-Hans | `iPhone Duo 双页对开阅读器` | 14 |
| zh-Hant | `iPhone Duo 雙頁對開閱讀器` | 14 |
| ja | `iPhone Duo 見開きリーダー` | 15 |

\* en 恰好 30 字符踩线,若 ASC 报错用备选:`Two-page books on iPhone Duo`(29)。
上架位置:App 信息 → 名称右侧副标题(每语言一个输入框)。

---

## B. en-US 关键词 100 字符(现 51,补近一半)

现值:
```
reader,epub,book,spread,foldable,duo,ebook,reading
```

替换为(**整串替换**,71/100 字符,一次过):
```
read,book,epub,reader,pdf,foldable,duo,spread,dual,screen,fold,two,page
```

词表说明(选词依据):
- `read,book`:大词照留(现 search impressions 大头来自泛词,维持入口)
- `pdf`:Info.plist 已声明 com.adobe.pdf 支持,白捡一个大流量词
- `foldable,fold,duo,dual,screen,two,page,spread`:Duo 意向词全占
- Apple 自动组合:epub reader / book reader / foldable reader / dual screen book...
- 不放:trilogy/iron vest 类自身无关联词;逗号后**不加空格**;不放 app 名自身

---

## C. en-US 描述(重写,受众过滤优先)

现版问题:三句式名词化开头读不出"给 Duo 的",泛流量看完也分不清是不是自己要的。

**整段替换为:**

```text
DuoFolio turns iPhone Duo into a book.

Unfold: your book opens across both displays as a two-page spread — even page
left, odd page right, a soft spine shadow down the middle. Like paper.

Fold: the cover display becomes a bookmark card — cover art, title, progress.
Reopen and you resume on the same column.

Import your books: AirDrop an EPUB or PDF, open it from Files, or drop it onto
DuoFolio in Finder. No account, no cloud.

· Automatic two-page spread when you rotate Duo sideways
· Cover-display bookmark: title, progress, cover art
· EPUB & PDF; themes and typography tuned for the fold
· Pure local: your books never touch a server

DuoFolio is built for iPhone Duo. Without a Duo it still runs as a clean,
private reader on any iPhone.

$6.99, one-time. Free updates.
```

要点:
- 首句动词化+受众钉死;旧版「a layout engine designed for the fold」工程腔已删
- 「Import your books」句按 Info.plist 实测能力写(EPUB+PDF/Open-in/AirDrop/Finder 文件共享全真,无夸大)
- 末段兼容声明收敛成一句;**价格锚「$6.99, one-time」放最后**——泛读者看到这行自动分流,留下的都是接受价格的
- 首屏截图(D 节)第一张换「$6.99 one-time」角标版后,可将价格行从描述删掉避免重复

---

## D. 6.7" iPhone 截图(2 旧 → 2 新替换,四语全上)

规格 **1290×2796**。线上现有 asc_67_01/02(md5 0afe93…/d5e324…)与本地新版不同 → 是旧拷贝,直接替换成 i18n 最新版并补齐:

| 顺序 | 文件(release/screenshots/i18n/) | 说明 |
|---|---|---|
| 1 | `<lang>/67_main.png` | 对开双页主图(四语各一张,替换线上 asc_67_01) |
| 2 | `<lang>/67_laptop.png` | 桌面场景图(新增,替换线上 asc_67_02) |

`<lang>` ∈ en / ja / zh-Hans / zh-Hant,即 **4 语言 × 2 图 = 8 次上传**,每语言槽位 2 张恰好用满规格校验(1290×2796 已核)。
注意:`duo.png`(2007×2853)是 APP_IPHONE_DUO 专属槽规格,不进 6.7" 槽。

---

## E. Promo Text(170 字符,免审核随时改)—— 四语全空,填掉

现在没降价时:先填"本地优先"声明(不提价格):

| 语言 | 文案 |
|---|---|
| en-US | `Pure local reading — your books never touch a server. Built for iPhone Duo.` |
| zh-Hans | `纯本地阅读,书不经过任何服务器。为 iPhone Duo 而生。` |
| zh-Hant | `純本地閱讀,書不經過任何伺服器。為 iPhone Duo 而生。` |
| ja | `完全ローカル reading。本はサーバーに触れない。iPhone Duo のために。` |

降价时替换(降到 $2.99 那一刻):
- en: `Launch pricing: $6.99 → $2.99 for a limited time. Two-page books on iPhone Duo.`
- zh-Hans: `限时 $6.99 → $2.99。iPhone Duo 双页对开阅读。`
- ja: `期間限定で $6.99 → $2.99。iPhone Duo の見開き読書。`

---

## F. 不动清单(明确不碰)

- zh/ja/zh-Hant 描述:现版质量高,场景词全齐,不动
- APP_IPHONE_DUO 专属槽(fold/unfold 2 张):已在线,Duo 用户搜索时显示,不动
- APP_IPAD 槽:各 1 张,及格,不动
- 名称 "DuoFolio":裸名,别动(改名要重审,收益为负)

---

## G. API 可推项(用户过目文案后助手执行,不用手贴)

- [ ] 四语 subtitle → PATCH `appStoreVersionLocalizations/{id}` 字段 `subtitle`
- [ ] en keywords → PATCH 同端点字段 `keywords`
- [ ] 四语 promo text → PATCH 同端点字段 `promotionalText`
- [ ] 8 张 6.7" 截图替换上传(范式 `release/screenshots/upload_ipad13.py`,槽位改 `APP_IPHONE_67`,版本 ID 用 1.0.4 `2b16f35f-716c-4766-95f0-372079635f4e`)

## H. 用户动作项(2026-11-13 更新:API 侧已全部推完,剩 3 步)

**API 已完成(免手贴):** promo 四语已生效(1.0.4 上直接改,线上即时可见);1.0.5 版本已建好并装配齐全
—— subtitle 四语、en 新描述、keywords 71/100、whatsNew、20 张截图(四语 67×2+DUO+iPad×2)。
desc/keywords/subtitle 因 ASC 锁定规则(无进行中版本时锁死)走 1.0.5 生效。

剩余 3 步(全部是你才能做的):
- [ ] **① build 上传**:Xcode 打开 DuoFolio(project.yml 已 bump 1.0.5/Build 8,xcodegen 已跑),
      直接 Product → Archive → Distribute(同签名证书)。build 8 上传后 ASC 会自动把 1.0.5 版本与
      build 8 配对(版本号匹配规则)。**不提交审核,只是把 build 挂上。**
- [ ] **② 核对 1.0.5 预览**:ASC 网页检查四语 listing(subtitle 截断/截图排序/描述格式),
      没问题后点「提交以供审核」——这是唯一触发审核的动作,时机你定
- [ ] **③ 降价 + promo 联动**(playbook 见 price-drop-playbook.md):建议提交审核同时把
      Tier 7→3 降价生效日定在过审当天,喊助手 API 替换 promo 为降价版文案

---

## 附:数据基线(改前)

上架 2026-10-20 起 6 周:Impressions 5563(搜索 4066/浏览 1497)→ 产品页 1330(CTR 23.9% ✅)
→ First-time downloads **6**(PV→DL 0.45% ❌,健康 25-35%)。
6 个买家:全 iPhone、US3/AE/KW/MY、来源 search 4/browse 1/app referrer 1。
匀速 1 份/周,零飞轮。改完 2 周后重拉同一漏斗对比 PV→DL 变化。
