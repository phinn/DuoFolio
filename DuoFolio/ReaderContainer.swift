import SwiftUI

/// 阅读器总装:引擎 + WebView + 浮层 chrome
struct ReaderContainer: View {
    let book: Book
    let library: LibraryModel
    var onBack: () -> Void

    @State private var engine: ReaderEngine?
    @State private var settings = ReaderSettings.standard

    var body: some View {
        Group {
            if let engine {
                ReaderChrome(engine: engine, onBack: onBack) {
                    FolioWebView(engine: engine)
                        .ignoresSafeArea()
                }
                .environment(\.readerSettings, $settings)
            } else {
                Color(uiColor: .systemBackground)
                    .overlay(ProgressView())
                    .task {
                        var s = settings
                        if let saved = library.settings { s = saved }
                        settings = s
                        engine = ReaderEngine(book: book, settings: s, position: book.position)
                        NSLog("[DuoFolio] reader engine created, hook activeEngine")
                        library.activeEngine = engine
                    }
            }
        }
        .onChange(of: engine?.position) { _, pos in
            guard let pos, let engine else { return }
            library.updatePosition(bookID: book.id, position: pos)
        }
        .onChange(of: settings) { _, s in
            engine?.apply(settings: s)
            library.saveSettings(s)
        }
    }
}

extension EnvironmentValues {
    private struct ReaderSettingsKey: EnvironmentKey {
        static let defaultValue: Binding<ReaderSettings> = .constant(.standard)
    }
    var readerSettings: Binding<ReaderSettings> {
        get { self[ReaderSettingsKey.self] }
        set { self[ReaderSettingsKey.self] = newValue }
    }
}
