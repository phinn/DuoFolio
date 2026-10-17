import Foundation
import Observation

/// 阅读器全局可调项
struct ReaderSettings: Codable, Equatable {
    var theme: FolioTheme = .paper
    /// pt,13–30
    var fontSize: Double = 19
    var serif: Bool = true
    var twoColumn: Bool = true
    static let standard = ReaderSettings()
}

/// 阅读位置:spine 章节序号 + 全书列分页后的页序号
struct FolioPosition: Codable, Equatable {
    var spineIndex: Int = 0
    var pageIndex: Int = 0
}

/// 单本书的阅读引擎:持有设置与位置,桥接 FolioBridge 驱动 WebView
@Observable
final class ReaderEngine {
    let book: Book
    private(set) var settings: ReaderSettings
    private(set) var position = FolioPosition()
    private(set) var spineCount = 0
    private(set) var pageCount = 0
    private(set) var chapterTitle = ""
    private(set) var isReady = false
    /// 当前是否双列对开(JS layout 回报)
    private(set) var isSpread = false
    /// 全书总列数(对开时 = 总"面"数)
    private(set) var totalCols = 0
    var showChrome = true
    weak var bridge: FolioBridge?

    init(book: Book, settings: ReaderSettings = .standard, position: FolioPosition? = nil) {
        self.book = book
        self.settings = settings
        if let position { self.position = position }
    }

    // MARK: WebView → Native(由 FolioBridge 调)

    func markReady(spineCount: Int) {
        self.spineCount = spineCount
        isReady = true
    }

    /// JS resize 回报管线状态(bridge 调用)
    func reportLayout(cols: Int, totalCols: Int) {
        isSpread = cols >= 2
        self.totalCols = totalCols
    }

    func update(spine: Int, page: Int, pageCount: Int, chapterTitle: String) {
        position = FolioPosition(spineIndex: spine, pageIndex: page)
        self.pageCount = pageCount
        self.chapterTitle = chapterTitle
        #if DEBUG
        NSLog("[DuoFolio] engine pos spine=\(spine) page=\(page)/\(pageCount)")
        #endif
    }

    // MARK: Native → WebView

    func nextPage() {
        bridge?.eval("""
        try { folio.next() } catch(e) { webkit?.messageHandlers?.folioBridge?.postMessage({t:'jserr', msg: String(e)}) }
        """)
        NSLog("[DuoFolio] next() sent, bridge=\(bridge != nil)")
    }
    func prevPage() {
        bridge?.eval("""
        try { folio.prev() } catch(e) { webkit?.messageHandlers?.folioBridge?.postMessage({t:'jserr', msg: String(e)}) }
        """)
    }

    func jump(pageIndex: Int) {
        bridge?.eval("folio.goto(\(pageIndex))")
    }

    func apply(settings: ReaderSettings) {
        self.settings = settings
        bridge?.applySettings()
    }
}
