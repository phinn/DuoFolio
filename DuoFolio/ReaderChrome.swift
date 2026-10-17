import SwiftUI

/// 阅读页浮层:顶部返回+章节,底部进度+设置。点正文呼出/隐藏。
struct ReaderChrome<Content: View>: View {
    @Bindable var engine: ReaderEngine
    var onBack: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.readerSettings) private var settings
    @State private var showSettings = false

    var body: some View {
        ZStack {
            content()
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        engine.showChrome.toggle()
                        if !engine.showChrome { showSettings = false }
                    }
                }

            VStack {
                topBar
                Spacer()
                if showSettings { settingsPanel }
                bottomBar
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: engine.showChrome)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: showSettings)
        }
    }

    private var topBar: some View {
        HStack(spacing: 18) {
            Button(action: onBack) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
            }
            VStack(spacing: 1) {
                Text(engine.book.title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                if !engine.chapterTitle.isEmpty {
                    Text(engine.chapterTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if engine.isReady, engine.pageCount > 0 {
                Text("\(engine.position.pageIndex + 1)/\(engine.pageCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .offset(y: engine.showChrome ? 0 : -120)
    }

    private var bottomBar: some View {
        HStack(spacing: 18) {
            Button { engine.prevPage() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
            }
            .disabled(!engine.isReady)

            // 进度滑条
            if engine.pageCount > 0 {
                Slider(
                    value: Binding(
                        get: { Double(engine.position.pageIndex) },
                        set: { v in engine.jump(pageIndex: Int(v)) }
                    ), in: 0...Double(max(0, engine.pageCount - 1))
                )
            } else {
                Spacer()
            }

            // 对开页码组:左页·右页(双列时显示,书页语义同印刷书)
            if engine.isSpread, engine.pageCount > 0 {
                Text("\(engine.position.pageIndex + 1)·\(min(engine.position.pageIndex + 2, engine.pageCount))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .help("两页对开")
            }

            Button { engine.nextPage() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .disabled(!engine.isReady)

            Button { showSettings.toggle() } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial)
        .offset(y: engine.showChrome ? 0 : 140)
    }

    private var settingsPanel: some View {
        VStack(spacing: 18) {
            // 主题
            HStack(spacing: 12) {
                ForEach(FolioTheme.allCases) { t in
                    themeButton(t)
                }
                Spacer()
                // 衬线切换
                Picker("", selection: settings.serif) {
                    Image(systemName: "textformat").tag(false)
                    Image(systemName: "font").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            // 字号
            HStack(spacing: 14) {
                Image(systemName: "textformat.size.smaller")
                Slider(value: settings.fontSize, in: 13...30, step: 1)
                Image(systemName: "textformat.size.larger")
            }
            // 双列开关(合盖时自动变单列,这里给手动强制)
            Toggle(isOn: settings.twoColumn) {
                Label("Two-page spread", systemImage: "rectangle.split.2x1")
                    .font(.footnote)
            }
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }
}

extension ReaderChrome {
    fileprivate func themeButton(_ t: FolioTheme) -> some View {
        let selected = settings.wrappedValue.theme == t
        let circle = Circle()
            .fill(t.color)
            .frame(width: 34, height: 34)
        let outlined = circle.overlay(Circle().strokeBorder(.quaternary, lineWidth: 1))
        let marked = Group {
            if selected {
                outlined.overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2))
            } else {
                outlined
            }
        }
        return Button { settings.wrappedValue.theme = t } label: { marked }
    }
}
