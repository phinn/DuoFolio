# DuoFolio · Featuring 提交备料(2026-11-13)

> 官方通路(已核实 developer.apple.com/app-store/getting-featured/):
> **App Store Connect 内的 Featuring Nominations 表单**(App 页面 → 提名/Nominations 区)。
> 官方要求:最少提前 **2 周**;想进宽覆盖(全球多区)提前至 **3 个月**。
> 编辑 curated 的对象:新 app / 重大更新 / In-App Events / 独特故事 / 文化时刻。

---

## 0. 依赖顺序(硬前提,别乱序)

编辑收到提名后**第一件事就是点开产品页**。当前产品页(2 张截图/0 评分/无副标题/泛化描述)过不了编辑 QC,
提名等于浪费一次机会(重新提名无冷却但印象分留在他们池子里)。

```
① conversion-fix.md 全部落地(免审核,当天生效)
② 评分≥5 且无 1 星(评分冲刺方案见本文件第 4 节)
③ 降价窗口制造转化数据(可选但强烈建议,见 price-drop.md)
④ v1.1 build 过审上架(哪怕小更新)——「重大更新」是标准提名入口
⑤ 提交 Featuring Nomination(v1.1 上架当天)
```

**结论:v1.1 别急着写代码。先走 ①②③,两三周后带数据提名。**

---

## 1. 故事角度(三选一或叠加,填表用)

| 角度 | 内容 | 强度 |
|---|---|---|
| **硬件时刻**(主推) | iPhone Duo 是 Apple 第一个折叠形态。书是折叠屏的"天选场景"——两页对开=纸质书。DuoFolio 是第一批原生适配的 EPUB 阅读器:展开双页/合盖即书签/封面态像一本书躺在桌上 | ★★★ 编辑永远在找"新硬件+经典场景"的首发故事 |
| 独立开发者 | 一人开发(22 款 App 全家桶的 solo dev),无服务器纯本地架构,上架 6 周零营销纯自然下载 | ★★ 支撑材料,单独不够 |
| 技术设计 | EPUB+PDF 双格式、对开渲染按 Duo 宽高比精调、合盖自动书签、暗色跟随系统 | ★ 配角 |

**推荐写法:硬件时刻为主轴,indie 一句带过,技术细节做附注。**

---

## 2. Nomination 表单文案(英文,直接粘贴)

> 表单字段以 ASC 实际 UI 为准;以下按标准字段备料,缺的字段就地取材。

**App / What are you nominating:**
```
Significant update — DuoFolio 1.1 (Books)
```

**Tell us about your app(核心栏,≤4000 字符):**
```
DuoFolio turns the iPhone Duo into a book.

When Apple introduced its first foldable, the most natural thing to do
with a bigger, bendable screen was also the oldest: read a book as two
pages. DuoFolio is a paid, one-time-purchase EPUB and PDF reader built
exclusively around that gesture.

· Unfold — spreads render side-by-side, tuned to the Duo's panel
· Fold — the app closes like a cover and keeps your place automatically
· On the table — the cover art rests on the front display, like a book
· Pure local — no account, no server, no tracking; books via AirDrop,
  Files, or Finder

A one-person studio makes it (22 apps shipped across the Kinet family).
No marketing, no ads — six weeks of organic downloads only. We'd love
the App Store editorial team to consider DuoFolio for a collection
around new form factors, foldable-first apps, or quiet reading tools.
```

**Timing / availability:**
```
Live worldwide in 19 storefronts. Update 1.1 ships [填 v1.1 实际周].
Best window: any foldable / hardware-moment editorial in the next 3 months.
```

**Assets(表单/附件区,现有库存全够):**
- App icon(1024)
- 截图:APP_IPHONE_DUO fold/unfold(已在产品页)+ 6.7" 新版 4 张(conversion-fix D 节传完后即最新)
- 宣传图:marketing/ 已有 warm-paper 1200×675(X 广告图,commit 32a234e)可复用;如表单要 16:9 视频,后补

---

## 3. 编辑 QC 自查(提交前逐项过)

- [ ] 产品页:副标题四语已填、6.7" 截图 2→4 张、en 描述重写版上线
- [ ] 评分:≥5 条全 4-5 星(App 页面无裸奔 0 分)
- [ ] 定价:降价窗口进行中或刚结束(promo text 有 "$6.99→$2.99" 记录也行)
- [ ] v1.1 已过审上架(提名挂在"重大更新"上,不是裸 app)
- [ ] 隐私标签/"数据不收集"声明干净(Books 类目编辑很看重)
- [ ] App 支持链接可访问(phinn.github.io/kinetapp 有 DuoFolio 卡)

---

## 4. 评分冲刺(前置依赖,机制)

现状 0 评分。预算:已有 6 个买家 + 未来买家。

1. **SKStoreReviewController.requestReview()**(系统评分弹窗,iOS 免费通路,每 app 每用户每年最多 3 次):
   - 触发点:第二次完整阅读会话结束(读完合盖那一刻=体验峰值),不是启动时
   - v1.1 加上,一次提交两个目的(更新+评分入口)
2. **邮件兜底**:设置页加 "Enjoy it? A rating helps a solo dev." 链接
   `itms-apps://itunes.apple.com/app/id6823855712?action=write-review`(直跳写评论)
3. **不做的**:换评/返现类(红线);TestFlight 评分不迁移(App Store 评分只算商店安装)

现实预期:6 周卖 6 份 → 评分爬到 5-10 条需要 1-2 个月(伴随降价窗口加速)。
**评分是 Featuring 的必要非充分项;5 条 5 星就能过编辑 QC 的裸线。**

---

## 5. 提交动作(手工,10 分钟)

ASC → 我的 App → DuoFolio → 侧栏 **提名/Featuring Nominations** → 新建:
1. 类型选 Significant update
2. 粘贴第 2 节文案,挂 2-3 张截图
3. 提交 → 等邮件(过/不过都有回执;被拒不改也不扣分,可随下个版本再提)

若 ASC 界面找不到提名入口(账号权限/区域 UI 差异),备用通路:
App Store 推广 contacts(开发者页 Contact Us 表单)提交同样内容。
