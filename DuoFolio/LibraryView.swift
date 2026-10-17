import SwiftUI
import UniformTypeIdentifiers

/// 书库 + 打开阅读器
struct LibraryView: View {
    @State var library: LibraryModel
    var coverState: FolioCoverState
    @State private var openedBook: Book?

    var body: some View {
        NavigationStack {
            ZStack {
                FolioTheme.paper.color.ignoresSafeArea()
                content
            }
            .navigationTitle("DuoFolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("书架")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(Color(red: 0.17, green: 0.16, blue: 0.15))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        library.presentImporter = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
            .overlay {
                if library.isImporting {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("正在打开…")
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .onChange(of: library.pendingOpen) { _, book in
                guard let book else { return }
                NSLog("[DuoFolio] onChange pendingOpen -> \(book.title), set openedBook")
                withAnimation(.easeOut(duration: 0.22)) {
                    openedBook = book
                    library.pendingOpen = nil
                }
            }
            .onChange(of: openedBook) { old, new in
                if new == nil { NSLog("[DuoFolio] reader dismissed (was \(old?.title ?? "nil"))") }
            }
            #if DEBUG
            .task {
                // 烟囱 harness:冷启动参数直开,绕过深链确认框。-duofolio.openIndex 0 [-duofolio.flip N]
                let args = ProcessInfo.processInfo.arguments
                // 真实书导入 harness:-duofolio.importPath /path/book.epub(复制进沙盒 Documents 再走导入)
                if let ii = args.firstIndex(of: "-duofolio.importPath"),
                   ii + 1 < args.count {
                    let src = URL(fileURLWithPath: args[ii + 1])
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let dst = docs.appendingPathComponent(src.lastPathComponent)
                    try? FileManager.default.removeItem(at: dst)
                    try? FileManager.default.copyItem(at: src, to: dst)
                    let copy = library
                    copy.importBook(from: dst)
                    NSLog("[DuoFolio] harness import \(src.lastPathComponent) books=\(copy.books.count)")
                }
                guard let i = args.firstIndex(of: "-duofolio.openIndex"),
                      i + 1 < args.count, let idx = Int(args[i + 1]) else { return }
                let copy = library
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard idx < copy.books.count else {
                    NSLog("[DuoFolio] harness index out of range books=\(copy.books.count)")
                    return
                }
                let book = copy.books[idx]
                await copy.open(book)
                NSLog("[DuoFolio] harness open index \(idx) ok")
                if let fi = args.firstIndex(of: "-duofolio.flip"),
                   fi + 1 < args.count, let n = Int(args[fi + 1]) {
                    // 等 WebView 布局完成(第一条 pos 回调后 pageCount>0)再翻,轮询上限 12s
                    var waited = 0.0
                    while (copy.activeEngine == nil || copy.activeEngine?.pageCount == 0), waited < 12 {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        waited += 0.3
                    }
                    NSLog("[DuoFolio] flip wait \(waited)s pageCount=\(copy.activeEngine?.pageCount ?? -1)")
                    for k in 0..<max(0, n) {
                        copy.activeEngine?.nextPage()
                        NSLog("[DuoFolio] flip \(k + 1)/\(n)")
                        try? await Task.sleep(nanoseconds: 450_000_000)
                    }
                }
                // 横屏 harness:-duofolio.landscape → 旋转触发 JS resize → 双列对开
                if args.contains("-duofolio.landscape") {
                    // 等 WebView 就绪
                    var w = 0.0
                    while copy.activeEngine?.pageCount == 0, w < 12 {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        w += 0.3
                    }
                    await MainActor.run {
                        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
                        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
                    }
                    NSLog("[DuoFolio] landscape requested")
                }
            }
            #endif
            .alert("导入失败", isPresented: .init(
                get: { library.importError != nil },
                set: { if !$0 { library.importError = nil } })) {
                Button("好", role: .cancel) {}
            } message: {
                Text(library.importError ?? "")
            }
            .fileImporter(isPresented: $library.presentImporter,
                          allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
                          allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    library.importBook(from: url)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let book = openedBook {
            ReaderContainer(book: book, library: library) {
                self.openedBook = nil
                coverState.endSession()
            }
            .onAppear { coverState.beginSession(book: book, library: library) }
            .onChange(of: library.books) { _, books in
                // 进度回写后刷新书签卡(封面/页码跟随)
                coverState.refresh(book: book, in: books, library: library)
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity))
        } else {
            shelf
        }
    }

    private var shelf: some View {
        Group {
            if library.books.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 128), spacing: 22)],
                              spacing: 26) {
                        ForEach(library.books) { book in
                            CoverCell(book: book) { openedBook = book }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        library.remove(book)
                                    } label: {
                                        Label("移出书架", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 26) {
            Spacer()
            // 双页书本 icon(自绘,呼应 Duo 双屏)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white)
                    .frame(width: 62, height: 88)
                    .rotation3DEffect(.degrees(-8), axis: (x: 0, y: 1, z: 0))
                    .shadow(color: .black.opacity(0.12), radius: 10, x: -4, y: 6)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.96, green: 0.94, blue: 0.90))
                    .frame(width: 62, height: 88)
                    .rotation3DEffect(.degrees(8), axis: (x: 0, y: 1, z: 0))
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 4, y: 6)
                Image(systemName: "text.book.closed")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Color(red: 0.72, green: 0.55, blue: 0.35))
            }
            VStack(spacing: 8) {
                Text("把书放进来")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                Text("右上角导入 EPUB,全本地阅读\n展开 iPhone Duo 即成双页对开")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

/// 封面格:有封面图用图,没有画纸感占位
struct CoverCell: View {
    let book: Book
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack {
                    if let d = book.coverData, let img = UIImage(data: d) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [Color(red: 0.93, green: 0.89, blue: 0.82),
                                                          Color(red: 0.88, green: 0.82, blue: 0.72)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(
                                Text(String(book.title.prefix(1)))
                                    .font(.system(size: 40, weight: .semibold, design: .serif))
                                    .foregroundStyle(Color(red: 0.42, green: 0.31, blue: 0.22))
                            )
                    }
                }
                .frame(height: 158)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.black.opacity(0.06)))
                .shadow(color: .black.opacity(0.10), radius: 6, y: 3)

                Text(book.title)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(book.author)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
