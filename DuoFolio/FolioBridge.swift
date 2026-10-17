import Foundation
import WebKit
import SwiftUI

/// Folio 排版桥:EPUB 全文装进单文档,CSS columns 分页(竖屏单列 / 横宽双列自动对开)。
/// 翻页 = translateX 步进;位置 = (spine, pageIndex) 回报原生层持久化。
final class FolioBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private unowned let engine: ReaderEngine
    private let webView: WKWebView
    private var loadedOnce = false
    /// 章节起始列号(由 JS 首次排版后回报)
    private var chapterColumns: [Int] = []

    private static let bridgeName = "folioBridge"

    init(webView: WKWebView, engine: ReaderEngine) {
        self.webView = webView
        self.engine = engine
        super.init()
        webView.configuration.userContentController.add(self, name: Self.bridgeName)
        webView.navigationDelegate = self
    }

    func teardown() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.bridgeName)
    }

    static func makeConfiguration() -> WKWebViewConfiguration {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.suppressesIncrementalRendering = false
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        cfg.defaultWebpagePreferences = prefs
        return cfg
    }

    // MARK: - 装载

    func load() {
        guard !loadedOnce else { return }
        loadedOnce = true
        let html = buildDocument()
        webView.loadHTMLString(html, baseURL: nil)
    }

    /// EPUB 全文 → 单 HTML 文档(资源已由 EpubBook 内联)
    private func buildDocument() -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(engine.book.fileName)
        guard let data = try? Data(contentsOf: url),
              let epub = try? EpubBook.parse(data: data) else {
            return fallbackDocument("无法解析这本书")
        }
        var body = ""
        for ch in epub.chapters {
            let html = epub.inlineResources(html: epub.readString(ch.href) ?? "", baseURL: epub.opfDir.isEmpty ? "" : epub.opfDir + "/")
            let title = ch.title.isEmpty ? "Chapter \(ch.id + 1)" : ch.title
            body += "<section class=\"chapter\"><h1 id=\"ch\(ch.id)\">\(Self.escape(title))</h1>\(html)</section>"
        }
        if body.isEmpty {
            return fallbackDocument("这本书没有可读内容")
        }
        let s = engine.settings
        let initial = engine.position
        return """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
        \(FolioAssets.readerCSS)
        </head><body>
        <div id="flow">\(body)</div>
        \(FolioAssets.readerJS(themeJSON: Self.themeJSON(s.theme), startSpine: initial.spineIndex, startPage: initial.pageIndex, serif: s.serif, size: s.fontSize))
        </body></html>
        """
    }

    private func fallbackDocument(_ msg: String) -> String {
        FolioAssets.readerCSS + "<body><p>\(msg)</p></body>"
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func themeJSON(_ t: FolioTheme) -> String {
        "{\"bg\":\"\(t.bg)\",\"fg\":\"\(t.fg)\",\"dim\":\"\(t.dim)\"}"
    }

    // MARK: - 设置

    func applySettings() {
        let s = engine.settings
        let js = """
        folio.style({bg:'\(s.theme.bg)',fg:'\(s.theme.fg)',dim:'\(s.theme.dim)'}, \(s.serif), \(Int(s.fontSize)));
        folio.setSpread(\(s.twoColumn));
        """
        eval(js)
    }

    func applyTheme() { applySettings() }

    func eval(_ js: String) {
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - JS → Native

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == Self.bridgeName,
              let d = message.body as? [String: Any],
              let t = d["t"] as? String else { return }
        switch t {
        case "layout":
            // 首次排版完成:章节→列映射 + 总页数
            if let cols = d["chapterCols"] as? [Int] { chapterColumns = cols }
            let total = d["total"] as? Int ?? 1
            engine.markReady(spineCount: chapterColumns.count)
            engine.update(spine: 0, page: 0, pageCount: total, chapterTitle: "")
        case "pos":
            let spine = d["spine"] as? Int ?? 0
            let col = d["col"] as? Int ?? 0
            let total = d["cols"] as? Int ?? 1
            let title = d["title"] as? String ?? ""
            engine.update(spine: spine, page: col, pageCount: total, chapterTitle: title)
        case "jserr":
            NSLog("[DuoFolio] JS error: \(d["msg"] ?? "?")")
        case "resize":
            NSLog("[DuoFolio] JS resize w=\(d["w"] ?? "?") h=\(d["h"] ?? "?") cols=\(d["cols"] ?? "?") total=\(d["total"] ?? "?")")
            engine.reportLayout(cols: d["cols"] as? Int ?? 1, totalCols: d["total"] as? Int ?? 0)
        default: break
        }
    }
}
