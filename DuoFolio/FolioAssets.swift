import Foundation

/// Folio 排版资产:注入 WebView 的 CSS + JS。
/// CSS 多列排版(Apple Books 同款分页机制):
///   #flow 设 column-width,整本书成横向长卷;翻页 = translateX 步进一个 column-width。
///   竖屏单列,横宽(w > h)自动双列对开,iPhone Duo 展开即成双页书。
enum FolioAssets {

    // MARK: - CSS

    static let readerCSS: String = """
    <style id="folio-css">
    * { margin:0; padding:0; box-sizing:border-box; -webkit-text-size-adjust:100%; }
    html, body { height:100%; overflow:hidden; }
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
      column-width: var(--colw);
      column-gap: var(--gap);
      column-fill: auto;
      height: 100%;
      padding: calc(env(safe-area-inset-top) + 44px) var(--pgap) calc(env(safe-area-inset-bottom) + 40px);
      will-change: transform;
    }
    .chapter { break-inside: auto; }
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

          let cols = 1, colW = 0, gap = 0, totalCols = 1, cur = 0;
          let chapterStarts = [];   // 每章起始列号
          const px = n => n + 'px';

          function layout() {
            const w = root.clientWidth, h = root.clientHeight;
            const wantSpread = document.body.dataset.forceCols
              ? parseInt(document.body.dataset.forceCols) : (w > h * 1.05 ? 2 : 1);
            cols = wantSpread;
            document.body.dataset.spread = cols;
            gap = cols === 2 ? Math.round(w * 0.055) : 0;
            const pgap = cols === 2 ? 34 : 26;
            root.style.setProperty('--pgap', px(pgap));
            // 实际列宽 = 内容区宽减去列间距,否则 translateX 步长与浏览器真实列周期不符 → 右列偏出屏幕
            colW = cols === 2 ? Math.round((w - 2 * pgap - gap) / 2) : w - 2 * pgap;
            root.style.setProperty('--colw', px(colW));
            root.style.setProperty('--gap', px(gap));
            const fs = parseFloat(root.dataset.size || '19');
            root.style.fontSize = px(Math.round(fs * (colW > 620 ? 1.12 : 1)));
            totalCols = Math.max(1, Math.round(flow.scrollWidth / (colW + gap)));
            // 章节起始列号
            chapterStarts = [];
            document.querySelectorAll('.chapter').forEach(el => {
              chapterStarts.push(Math.round(el.offsetLeft / (colW + gap)));
            });
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
            cur = Math.min(Math.max(0, i), totalCols - 1);
            const x = cur * (colW + gap);
            flow.style.transition = instant ? 'none' : 'transform .3s cubic-bezier(.32,.72,.35,1)';
            flow.style.transform = 'translateX(' + (-x) + 'px)';
            report();
          }

          function report() {
            const [sp, title] = chapterAt(cur);
            send({ t:'pos', spine: sp, col: cur, cols: totalCols, title });
            pageNum();
          }

          function pageNum() {
            let el = document.getElementById('folioPageNum');
            if (!el) { el = document.createElement('div'); el.id = 'folioPageNum'; document.body.appendChild(el); }
            el.textContent = (cur + 1) + ' / ' + totalCols;
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
          layout();
          // 初始位置:spine 对应章起始列 + 章内页偏移
          const startSpine = \(startSpine), startPage = \(startPage);
          const base = chapterStarts[Math.min(startSpine, chapterStarts.length - 1)] || 0;
          cur = Math.min(base + startPage, totalCols - 1);
          goto(cur, true);
          send({ t:'layout', chapterCols: chapterStarts, total: totalCols });

          return { next, prev, goto, style, setSpread };
        })();
        </script>
        """
    }
}
