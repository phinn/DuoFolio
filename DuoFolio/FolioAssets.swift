import Foundation

/// Folio 排版资产:注入 WebView 的 CSS + JS。
/// CSS 多列排版(Apple Books 同款分页机制):
///   #flow 设 column-width,整本书成横向长卷;翻页 = translateX 步进一个 column-width。
///   竖屏单列,横宽(w > h)自动双列对开,iPhone Duo 展开即成双页书。
/// 双列对开时正文从右页(奇数列)起:#flow 开头注入一个空白占位列(列 0),
///   正文第 1 页落在列 1(右页),实现「左偶右奇」的印刷书页序;每章再靠
///   .spread-void 补齐,强制新章从右页起。
enum FolioAssets {

    // MARK: - CSS

    static let readerCSS: String = """
    <style id="folio-css">
    * { margin:0; padding:0; box-sizing:border-box; -webkit-text-size-adjust:100%; }
    :root { --sal: env(safe-area-inset-left); --sar: env(safe-area-inset-right); }
    html, body { height:100%; overflow:hidden; }
    /* 书籍 CSS 常带 body{margin:10%}(Gutenberg @media screen),会把 #flow 挤到
       单列宽导致对开失效;host 用 !important 钉死,后到的书籍声明也压不过 */
    html, body { margin:0 !important; padding:0 !important; width:auto !important; }
    body {
      font-family: 'Iowan Old Style', 'Palatino', 'Georgia', serif;
      background: var(--bg); color: var(--fg);
      -webkit-font-smoothing: antialiased;
      transition: background .4s ease, color .4s ease;
    }
    #viewport {
      position: fixed; inset: 0;
      overflow: hidden;
    }
    #flow {
      column-count: var(--colcount, 1);
      column-gap: var(--gap);
      column-fill: auto;
      height: 100%;
      padding: calc(env(safe-area-inset-top) + 44px) var(--pgapr) calc(env(safe-area-inset-bottom) + 40px) var(--pgapl);
      will-change: transform;
    }
    .chapter { break-inside: auto; }
    /* 双列对开时的空白占位列:高度撑满一列(由 JS 精确设 px),强制后续内容换列 */
    .spread-void { width:100%; height:100%; break-after:column; }
    body:not([data-spread="2"]) .spread-void { display:none; }
    /* 书籍自带 CSS 在 body 内联、晚于本表生效,注入元素与替换元素须 !important 钉死 */
    #flow svg, #flow img { max-width:100% !important; max-height:100% !important; }
    #flow h1.folio-chtitle {
      font-family: -apple-system, 'SF Pro Display', sans-serif;
      font-size:.8em !important; font-weight:600 !important; letter-spacing:.16em !important;
      text-transform:uppercase !important; color:var(--dim) !important;
      margin:1.6em 0 2.4em !important; break-before: column;
    }
    #flow section:first-of-type h1.folio-chtitle { break-before: auto; margin-top:.4em; }
    h1 {
      font-family: -apple-system, 'SF Pro Display', sans-serif;
      font-size:.8em; font-weight:600; letter-spacing:.16em; text-transform:uppercase;
      color: var(--dim); margin: 1.6em 0 2.4em;
      break-before: column;
    }
    .chapter:first-of-type h1 { break-before: auto; margin-top:.4em; }
    p { font-size:1em; line-height:1.74; text-align:justify; hyphens:auto; -webkit-hyphens:auto;
        text-indent:1.6em; margin:0; orphans:2; widows:2; }
    p + p { margin-top:.18em; }
    h1 + p, h2 + p, h3 + p, blockquote + p { text-indent:0; }
    h2, h3 { font-family:-apple-system,sans-serif; font-weight:650; break-after:avoid;
             margin:1.6em 0 .7em; font-size:1.04em; }
    em { font-style:italic; }
    blockquote { margin:1em 1.4em; padding-left:.9em; border-left:2px solid var(--dim);
                 font-style:italic; color:var(--dim); }
    img { max-width:100%; height:auto; display:block; margin:1em auto;
          break-inside:avoid; border-radius:4px; }
    hr { border:0; text-align:center; margin:1.3em 0; break-inside:avoid; }
    hr::after { content:'❦'; color:var(--dim); font-size:.9em; letter-spacing:.5em; }
    a { color:inherit; text-decoration:none; }
    ::selection { background: rgba(176,125,79,.30); }
    #folioPageNum {
      position:fixed; bottom:calc(env(safe-area-inset-bottom) + 12px); left:0; right:0;
      text-align:center; font:500 10px -apple-system; letter-spacing:.22em;
      color:var(--dim); opacity:.72; pointer-events:none;
      font-variant-numeric: tabular-nums;
    }
    /* 双列对开时的中缝阴影 */
    body[data-spread="2"] #gutter {
      position:fixed; top:0; bottom:0; left:50%; width:0;
      transform: translateX(-50%); pointer-events:none; z-index:5;
      box-shadow: 0 0 18px rgba(0,0,0,.16);
    }
    /* 对开左右页码(书页角标,左偶右奇,同 Apple Books) */
    body[data-spread="2"] .folioPg {
      position:fixed; bottom:calc(env(safe-area-inset-bottom) + 12px);
      font:500 10px -apple-system; letter-spacing:.18em; color:var(--dim);
      opacity:.72; pointer-events:none; font-variant-numeric: tabular-nums; z-index:6;
    }
    body[data-spread="2"] #folioPgL { left:calc(env(safe-area-inset-left) + 26px); }
    body[data-spread="2"] #folioPgR { right:calc(env(safe-area-inset-right) + 26px); }
    /* 单列时隐藏角标,只留中央页码 */
    body:not([data-spread="2"]) .folioPg { display:none; }
    </style>
    """

    // MARK: - JS

    static func readerJS(themeJSON: String, startSpine: Int, startPage: Int,
                         serif: Bool, size: Double) -> String {
        """
        <script id="folio-js">
        window.folio = (() => {
          const flow = document.getElementById('flow');
          const root = document.documentElement;
          const gutter = document.createElement('div'); gutter.id = 'gutter';
          document.body.appendChild(gutter);
          const send = m => window.webkit?.messageHandlers.folioBridge.postMessage(m);

          const theme = \(themeJSON);
          for (const k of ['bg','fg','dim']) root.style.setProperty('--' + k, theme[k]);
          root.style.setProperty('--serif', \(serif) ? "'Iowan Old Style','Palatino',Georgia,serif" : "-apple-system,'SF Pro Text',sans-serif");
          document.body.style.fontFamily = root.style.getPropertyValue('--serif');
          root.dataset.size = '\(size)';

          let cols = 1, colW = 0, gap = 0, totalCols = 1, cur = 0, period = 1, padL = 0, padR = 0;
          let chapterStarts = [];   // 每章起始列号
          const px = n => n + 'px';

          // 空白占位列高度 = 一列内容高(flow 高度减上下 padding);void 需精确占满一列,
          // break-after:column 才能把后续内容推到下一列
          function syncVoidHeights() {
            const cs = getComputedStyle(flow);
            const padTop = parseFloat(cs.paddingTop) || 0;
            const padBottom = parseFloat(cs.paddingBottom) || 0;
            const h = flow.clientHeight - padTop - padBottom;
            document.querySelectorAll('.spread-void').forEach(e => { e.style.height = px(h); });
          }

          function measureChapterStarts() {
            const starts = [];
            document.querySelectorAll('.chapter').forEach(el => {
              starts.push(Math.round((el.offsetLeft - padL) / period));
            });
            return starts;
          }

          // 所有空白占位列号(升序):含 #flow 开头占位列 + 每章补齐的 chapter-void。
          // 正文页码 = 列号 - 前方占位列数 + 1,这样空白页不编号、正文页号连续。
          function voidCols() {
            const v = [];
            document.querySelectorAll('.spread-void').forEach(e => {
              v.push(Math.round((e.offsetLeft - padL) / period));
            });
            return v.sort((a, b) => a - b);
          }

          // 双列对开:每章强制从右页(奇数列)起。multicol 的 break-before:column 只能换列、
          // 不保证奇偶,故运行时补齐:凡起始列是偶数(左页)的章节,前插一个 void 推到右页。
          // 每轮只插一个并重测,避免连锁误判;守卫上限防死循环。
          function alignChapters() {
            if (cols !== 2) return;
            document.querySelectorAll('.chapter-void').forEach(e => e.remove());
            let guard = 0;
            while (guard++ < 60) {
              syncVoidHeights();
              const sections = document.querySelectorAll('.chapter');
              const starts = measureChapterStarts();
              let inserted = false;
              for (let i = 0; i < starts.length; i++) {
                if (starts[i] % 2 === 0) {
                  const d = document.createElement('div');
                  d.className = 'spread-void chapter-void';
                  sections[i].before(d);
                  inserted = true;
                  break;
                }
              }
              if (!inserted) break;
            }
            syncVoidHeights();
          }

          function layout() {
            const w = root.clientWidth, h = root.clientHeight;
            const wantSpread = document.body.dataset.forceCols
              ? parseInt(document.body.dataset.forceCols) : (w > h * 1.05 ? 2 : 1);
            cols = wantSpread;
            document.body.dataset.spread = cols;
            gap = cols === 2 ? Math.round(w * 0.055) : 0;
            // 横屏刘海/圆角的左右 safe-area 计入左右 padding,保证列宽精确
            const sal = parseFloat(getComputedStyle(root).getPropertyValue('--sal')) || 0;
            const sar = parseFloat(getComputedStyle(root).getPropertyValue('--sar')) || 0;
            let pgapl = (cols === 2 ? 34 : 26) + sal, pgapr = (cols === 2 ? 34 : 26) + sar;
            // 全整数化:内容宽凑偶数(左 padding 吸收 1px),列宽/步长与浏览器逐像素一致,杜绝串列渗漏
            const contentW = w - pgapl - pgapr;
            if (cols === 2 && (contentW - gap) % 2 !== 0) { pgapl += 1; }
            const cw = w - pgapl - pgapr;
            root.style.setProperty('--pgapl', px(pgapl));
            root.style.setProperty('--pgapr', px(pgapr));
            padL = pgapl; padR = pgapr;
            // 显式列数:WebKit 对 column-width 的取整判定会差 1px 退化成单列
            root.style.setProperty('--colcount', String(cols));
            root.style.setProperty('--gap', px(gap));
            // 列周期初值;随后从 DOM 实测
            colW = (cw - gap) / cols;
            period = colW + gap;
            const fs = parseFloat(root.dataset.size || '19');
            root.style.fontSize = px(Math.round(fs * (colW > 620 ? 1.12 : 1)));
            syncVoidHeights();
            measurePeriod();
            alignChapters();
            totalCols = Math.max(1, Math.round((flow.scrollWidth - padL - padR) / period));
            chapterStarts = measureChapterStarts();
          }

          // 实测列几何:全书段落宽度中位数 = 真实列宽(表格/题头里的窄段落不占主流)
          function measurePeriod() {
            try {
              const ws = [];
              document.querySelectorAll('#flow p').forEach(p => {
                ws.push(p.getBoundingClientRect().width);
              });
              if (ws.length < 10) return;
              ws.sort((a, b) => a - b);
              const med = ws[Math.floor(ws.length / 2)];
              if (med > 80 && med < root.clientWidth) {
                colW = med;
                period = med + gap;
              }
            } catch (e) { /* 保初值 */ }
          }

          function chapterAt(col) {
            let sp = 0, title = '';
            const hs = document.querySelectorAll('.chapter');
            for (let i = 0; i < chapterStarts.length; i++) {
              if (chapterStarts[i] <= col) { sp = i; }
            }
            const el = hs[sp];
            if (el) title = el.dataset.title || '';
            return [sp, title];
          }

          function goto(i, instant) {
            // 对开对齐:双列时把起点吸附到偶数列(左页=偶,右页=奇),边界内有效
            let target = Math.min(Math.max(0, i), totalCols - 1);
            if (cols === 2) {
              target = Math.floor(target / 2) * 2;
              if (target > totalCols - 1) target = Math.max(0, totalCols - 2);
            }
            cur = target;
            const x = cur * period;
            flow.style.transition = instant ? 'none' : 'transform .3s cubic-bezier(.32,.72,.35,1)';
            flow.style.transform = 'translateX(' + (-x) + 'px)';
            report();
          }

          function report() {
            const [sp, title] = chapterAt(cur);
            // 正文页码 = 跳过所有空白占位列后的 1-based 序号(开头 void 与章节补齐 void 均不编号)
            let page, pages, leftPg, rightPg;
            if (cols === 2) {
              const voids = voidCols();
              pages = Math.max(0, totalCols - voids.length);
              const bodyOf = col => col - voids.filter(v => v < col).length + 1;
              const rightCol = cur + 1;
              const hasRight = rightCol < totalCols;
              const curVoid = voids.includes(cur);
              const rightVoid = voids.includes(rightCol);
              leftPg = (cur > 0 && !curVoid) ? bodyOf(cur) : 0;
              rightPg = (hasRight && !rightVoid) ? bodyOf(rightCol) : 0;
              page = rightPg > 0 ? rightPg : (leftPg > 0 ? leftPg : 1);
            } else {
              pages = totalCols;
              page = cur + 1;
              leftPg = 0; rightPg = 0;
            }
            send({ t:'pos', spine: sp, col: cur, cols: totalCols, page: page, pages: pages, left: leftPg, right: rightPg, title: title });
            pageNum();
          }

          function pageNum() {
            // 中央页码:单列=当前页;对开=左右页角标(左偶右奇,空白页不显示)
            let el = document.getElementById('folioPageNum');
            if (!el) { el = document.createElement('div'); el.id = 'folioPageNum'; document.body.appendChild(el); }
            let pl = document.getElementById('folioPgL'),
                pr = document.getElementById('folioPgR');
            if (!pl) {
              pl = document.createElement('div'); pl.id = 'folioPgL'; pl.className = 'folioPg';
              pr = document.createElement('div'); pr.id = 'folioPgR'; pr.className = 'folioPg';
              document.body.appendChild(pl); document.body.appendChild(pr);
            }
            if (cols === 2) {
              el.textContent = '';
              const voids = voidCols();
              const bodyOf = col => col - voids.filter(v => v < col).length + 1;
              const rightCol = cur + 1;
              pl.textContent = (cur > 0 && !voids.includes(cur)) ? String(bodyOf(cur)) : '';
              pr.textContent = (rightCol < totalCols && !voids.includes(rightCol)) ? String(bodyOf(rightCol)) : '';
            } else {
              el.textContent = (cur + 1) + ' / ' + totalCols;
              pl.textContent = ''; pr.textContent = '';
            }
          }

          function next() { goto(cur + cols, false); }
          function prev() { goto(cur - cols, false); }

          function style(s, serif, size) {
            for (const k of ['bg','fg','dim']) root.style.setProperty('--' + k, s[k]);
            document.body.style.fontFamily = serif ? "'Iowan Old Style','Palatino',Georgia,serif" : "-apple-system,'SF Pro Text',sans-serif";
            root.dataset.size = size;
            layout(); goto(cur, true);
          }

          function setSpread(on) {
            document.body.dataset.forceCols = on ? '' : '1';
            layout(); goto(cur, true);
          }

          // 触摸翻页:左右 30% 热区
          let sx = 0, sy = 0, st = 0;
          document.addEventListener('touchstart', e => {
            sx = e.touches[0].clientX; sy = e.touches[0].clientY; st = Date.now();
          }, {passive:true});
          document.addEventListener('touchend', e => {
            const dx = e.changedTouches[0].clientX - sx, dy = e.changedTouches[0].clientY - sy;
            if (Date.now() - st > 600 || Math.abs(dx) < 24) return;
            if (Math.abs(dy) > Math.abs(dx) * 1.4) return;
            if (dx < 0) next(); else prev();
          }, {passive:true});

          window.addEventListener('resize', () => { layout(); goto(cur, true); send({t:'resize', w: root.clientWidth, h: root.clientHeight, cols: cols, total: totalCols}); });
          // 图片/内联 SVG 等资源晚于首排版就绪会改变列盒:load 后防抖重排
          const relayoutSoon = (() => { let t; return () => { clearTimeout(t); t = setTimeout(() => { layout(); goto(cur, true); }, 120); }; })();
          document.querySelectorAll('#flow img, #flow svg').forEach(el => el.addEventListener('load', relayoutSoon));
          window.addEventListener('load', relayoutSoon);
          layout();
          // 初始位置:pageIndex 即全书绝对列号(0-based,含空白占位列),直接落列,再由 goto 吸附偶数列
          const startSpine = \(startSpine), startPage = \(startPage);
          cur = Math.min(startPage, totalCols - 1);
          goto(cur, true);
          send({ t:'layout', chapterCols: chapterStarts, total: totalCols, spread: cols });

          return { next, prev, goto, style, setSpread };
        })();
        </script>
        """
    }
}
