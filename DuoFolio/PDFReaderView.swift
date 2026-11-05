import SwiftUI
import PDFKit

/// PDF 阅读器:PDFKit 渲染,连续滚动;横屏/宽屏自动双页对开
struct PDFReaderView: View {
    let book: Book
    let library: LibraryModel
    var onBack: () -> Void

    @State private var pdfDoc: PDFDocument?
    @State private var pageCount = 0
    @State private var currentPage = 0
    @State private var goTarget: Int?
    @State private var twoUp = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏:返回 + 书名 + 页码
            ZStack {
                Text(book.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .lineLimit(1)
                    .padding(.horizontal, 90)
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .padding(.leading, 14)
                    Spacer()
                    if pageCount > 0 {
                        Text("\(currentPage + 1) / \(pageCount)")
                            .font(.system(size: 12, design: .serif).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 14)
                    }
                }
            }
            .frame(height: 44)
            .background(.bar)

            if let pdfDoc {
                PDFKitView(doc: pdfDoc, goTarget: $goTarget, currentPage: $currentPage, twoUp: twoUp)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                Color(uiColor: .systemBackground)
                    .overlay(ProgressView())
            }
        }
        .task {
            guard let url = library.fileURL(of: book),
                  let doc = PDFDocument(url: url) else {
                library.importError = "无法打开 PDF:\(book.fileName)"
                onBack()
                return
            }
            pdfDoc = doc
            pageCount = doc.pageCount
            if let pos = book.position, pos.pageIndex > 0 {
                goTarget = min(pos.pageIndex, doc.pageCount - 1)
            }
        }
        .onChange(of: currentPage) { _, page in
            guard pageCount > 0 else { return }
            library.updatePosition(bookID: book.id,
                                   position: FolioPosition(spineIndex: 0, pageIndex: page))
        }
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width > proxy.size.height
        } action: { landscape in
            twoUp = landscape
        }
    }
}

/// PDFKit 包装:双页切换 + 页变化回调
private struct PDFKitView: UIViewRepresentable {
    let doc: PDFDocument
    @Binding var goTarget: Int?
    @Binding var currentPage: Int
    var twoUp: Bool

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayDirection = .vertical
        v.backgroundColor = UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 1)
        v.document = doc
        v.delegate = context.coordinator
        return v
    }

    func updateUIView(_ v: PDFView, context: Context) {
        let want: PDFDisplayMode = twoUp ? .twoUpContinuous : .singlePageContinuous
        if v.displayMode != want { v.displayMode = want }
        if let t = goTarget {
            if let page = doc.page(at: t) {
                v.go(to: PDFDestination(page: page, at: .zero))
            }
            goTarget = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PDFViewDelegate {
        let parent: PDFKitView
        init(_ p: PDFKitView) { parent = p }

        func pdfViewPageChanged(_ notification: Notification) {
            guard let v = notification.object as? PDFView,
                  let page = v.currentPage else { return }
            let idx = v.document?.index(for: page) ?? 0
            DispatchQueue.main.async { self.parent.currentPage = idx }
        }
    }
}
