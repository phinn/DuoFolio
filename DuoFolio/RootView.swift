import SwiftUI

struct RootView: View {
    @State private var library = LibraryModel()
    /// 合盖书签卡状态(阅读会话期间活跃)
    @State private var coverState = FolioCoverState()

    var body: some View {
        LibraryView(library: library, coverState: coverState)
        .onOpenURL { url in
            // 外部「用 DuoFolio 打开」:接收 epub/pdf 文件并导入书库
            if url.isFileURL {
                let ext = url.pathExtension.lowercased()
                if ext == "epub" || ext == "pdf" {
                    library.importBook(from: url)
                }
                return
            }
            #if DEBUG
            // duofolio://open?index=N 烟囱深链
            guard url.scheme == "duofolio", url.host == "open",
                  let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let raw = comps.queryItems?.first(where: { $0.name == "index" })?.value,
                  let i = Int(raw), library.books.indices.contains(i) else { return }
            library.open(library.books[i])
            #endif
        }
        // 素材产线 harness:SIMCTL_CHILD_DF_OPEN_INDEX=0 simctl launch … 直开书,免深链确认弹窗
        .onAppear {
            if library.pendingOpen == nil,
               let raw = ProcessInfo.processInfo.environment["DF_OPEN_INDEX"],
               let i = Int(raw), library.books.indices.contains(i) {
                library.open(library.books[i])
            }
        }
        // iPhone Duo 合盖态:外屏书签卡(iOS 27.1)。无阅读会话时自动空。
        .modifier(FolioCoverSceneAccessory(state: coverState))
    }
}
