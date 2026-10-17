import SwiftUI
import Observation

/// iPhone Duo 合盖态外屏书签卡(iOS 27.1 sceneAccessory):
/// 内屏正在阅读时合上盖子,外屏以非交互 accessory 呈现当前书的
/// 封面缩略 + 书名 + 阅读进度,翻盖解锁回到内屏即从书签续读。
///
/// 呈现链路(M5Chat DuoExternalStatus 同款,TechTalks 111464):
/// RootView .sceneAccessory { FolioCoverCard(...) }
///   └─ availability == .available(合盖) 时系统把 content 投到外屏
///
/// 设计要点:
/// - ExternalNonInteractiveAccessory:合盖态外屏不可交互,卡片只读展示
/// - 引擎位置实时回写 library(Book.position),卡片每次合盖拿最新进度
/// - 无进度书显示"未开始",正在读的书显示 页/总页 + 进度条

/// 外屏书签卡内容(纯 SwiftUI,由系统在合盖时投到外屏)
struct FolioCoverCard: View {
    let title: String
    let author: String
    let coverData: Data?
    /// 已读列数(全书列分页后),从 0 起
    let page: Int
    /// 全书总列数
    let pageCount: Int

    private var progress: Double {
        guard pageCount > 0 else { return 0 }
        return min(1, Double(page + 1) / Double(pageCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                coverThumb
                VStack(alignment: .leading, spacing: 4) {
                    Text("继续阅读")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(2)
                    if !author.isEmpty {
                        Text(author)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            if pageCount > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .tint(.accentColor)
                    Text(pageCount > 0 ? "第 \(page + 1) 面 · 共 \(pageCount) 面" : "未开始")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("翻开盖子,从上次的地方继续")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var coverThumb: some View {
        if let data = coverData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.18))
                Image(systemName: "book.closed")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 44, height: 60)
        }
    }
}

/// 书签卡驱动器:轮询当前阅读引擎,向 RootView 暴露「该不该呈现 + 数据」。
/// @MainActor + @Observable,RootView 持有并喂给 sceneAccessory。
@MainActor
@Observable
final class FolioCoverState {
    /// 合盖 accessory 是否应有内容(有活动阅读会话时 true)
    private(set) var isActive: Bool = false
    private(set) var title: String = ""
    private(set) var author: String = ""
    private(set) var coverData: Data?
    private(set) var page: Int = 0
    private(set) var pageCount: Int = 0

    private weak var engine: ReaderEngine?
    private var pollTask: Task<Void, Never>?

    /// ReaderContainer 出现后调用:启动轮询,引擎位置变化 ≤0.5s 反映到卡片。
    func beginSession(book: Book, library: LibraryModel) {
        guard engine?.book.id != book.id else { return }
        title = book.title
        author = book.author
        coverData = book.coverData
        engine = library.activeEngine
        page = engine.map { $0.position.pageIndex } ?? 0
        pageCount = engine.map { $0.pageCount } ?? 0
        isActive = true
        #if DEBUG
        NSLog("[DuoFolio] cover session begin: \(book.title), engine=\(engine != nil)")
        #endif
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                if let self, let e = self.engine {
                    if e.position.pageIndex != self.page || e.pageCount != self.pageCount {
                        self.page = e.position.pageIndex
                        self.pageCount = e.pageCount
                    }
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    /// 进度回写后刷新元数据;引擎延迟就绪时补挂(开书瞬间 activeEngine 可能还没建好)
    func refresh(book: Book, in books: [Book], library: LibraryModel) {
        guard isActive else { return }
        if let nb = books.first(where: { $0.id == book.id }) {
            title = nb.title
            author = nb.author
            coverData = nb.coverData
        }
        if engine == nil, let e = library.activeEngine {
            engine = e
            pageCount = e.pageCount
            page = e.position.pageIndex
        }
    }

    func endSession() {
        pollTask?.cancel()
        pollTask = nil
        engine = nil
        isActive = false
        title = ""
        author = ""
        coverData = nil
        page = 0
        pageCount = 0
    }
}

/// sceneAccessory 内容装配(与 M5Chat DuoExternalStatusAccessory 同构):
/// iOS 27.1 SDK。呈现开关 = ExternalNonInteractiveAccessory 的 isEnabled:
/// 有活动阅读会话时 true;系统只在合盖(外屏 accessory 呈现时机)才真正显示。
/// 注:本 SDK 无 AvailabilityContext/devicePosture 查询 API,合盖判定由系统接管。
@available(iOS 27.1, *)
struct FolioCoverAccessory: SceneAccessoryContent {
    let state: FolioCoverState

    var body: some SceneAccessoryContent {
        ExternalNonInteractiveAccessory(isEnabled: Binding(get: { state.isActive }, set: { _ in })) {
            FolioCoverCard(
                title: state.title,
                author: state.author,
                coverData: state.coverData,
                page: state.page,
                pageCount: state.pageCount
            )
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.08))
        }
    }
}

/// ViewModifier 包一层 #available,让 sceneAccessory 挂载点对旧系统安全
struct FolioCoverSceneAccessory: ViewModifier {
    let state: FolioCoverState

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.sceneAccessory {
                FolioCoverAccessory(state: state)
            }
        } else {
            content
        }
    }
}
