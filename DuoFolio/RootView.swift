import SwiftUI

struct RootView: View {
    @State private var library = LibraryModel()
    /// 合盖书签卡状态(阅读会话期间活跃)
    @State private var coverState = FolioCoverState()

    var body: some View {
        LibraryView(library: library, coverState: coverState)
        #if DEBUG
        .onOpenURL { url in
            // duofolio://open?index=N 烟囱深链
            guard url.scheme == "duofolio", url.host == "open",
                  let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let raw = comps.queryItems?.first(where: { $0.name == "index" })?.value,
                  let i = Int(raw), library.books.indices.contains(i) else { return }
            library.open(library.books[i])
        }
        #endif
        // iPhone Duo 合盖态:外屏书签卡(iOS 27.1)。无阅读会话时自动空。
        .modifier(FolioCoverSceneAccessory(state: coverState))
    }
}
