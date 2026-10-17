import Foundation
import Observation

/// 全局书架状态:书单 JSON 持久化 + 文件导入 + 元数据解析
@Observable
final class LibraryModel {
    private(set) var books: [Book] = []
    var isImporting = false
    var presentImporter = false
    var importError: String?
    var settings: ReaderSettings?
    /// 待打开的书(LibraryView 监听它切到阅读器)
    var pendingOpen: Book?
    /// 当前显示中的阅读器引擎(harness/外部驱动入口)
    weak var activeEngine: ReaderEngine?

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("duofolio.json")
    }
    private static var settingsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("duofolio.settings.json")
    }

    init() {
        load()
        if let data = try? Data(contentsOf: Self.settingsURL),
           let s = try? JSONDecoder().decode(ReaderSettings.self, from: data) {
            settings = s
        }
    }

    func saveSettings(_ s: ReaderSettings) {
        settings = s
        if let data = try? JSONEncoder().encode(s) {
            try? data.write(to: Self.settingsURL, options: .atomic)
        }
    }

    // MARK: - 持久化

    /// 兼容 ISO8601 字符串与 double 两种日期格式(外部工具造索引时用 ISO 更可读)
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            if let s = try? c.decode(String.self) {
                let f = ISO8601DateFormatter()
                if let date = f.date(from: s) { return date }
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = f.date(from: s) { return date }
            }
            if let t = try? c.decode(Double.self) {
                return Date(timeIntervalSinceReferenceDate: t)
            }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "bad date")
        }
        return d
    }()

    private func load() {
        if let data = try? Data(contentsOf: Self.fileURL),
           var list = try? Self.decoder.decode([Book].self, from: data) {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            list = list.filter { b in
                FileManager.default.fileExists(atPath: docs.appendingPathComponent(b.fileName).path)
            }
            books = list
            NSLog("[DuoFolio] load ok: %ld books", books.count)
        } else {
            NSLog("[DuoFolio] load FAILED at %@", Self.fileURL.path)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: - 打开书

    /// 打开一本已导入的书(harness 直开也走这里)
    @MainActor
    func open(_ book: Book) {
        guard let url = fileURL(of: book) else {
            importError = "找不到书籍文件:\(book.fileName)"
            return
        }
        isImporting = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                _ = try EpubBook.parse(data: Data(contentsOf: url))
                await MainActor.run {
                    self.pendingOpen = book
                    self.isImporting = false
                }
            } catch {
                await MainActor.run {
                    self.isImporting = false
                    self.importError = "无法打开:\(error.localizedDescription)"
                }
            }
        }
    }

    func fileURL(of book: Book) -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(book.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - 导入

    func importBook(from url: URL) {
        isImporting = true
        defer { isImporting = false }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "\(UUID().uuidString).epub"
            let dest = docs.appendingPathComponent(fileName)
            try FileManager.default.copyItem(at: url, to: dest)

            let epub = try EpubBook.parse(data: try Data(contentsOf: dest))
            let book = Book(id: UUID(), title: epub.title, author: epub.author,
                            fileName: fileName, coverData: epub.coverImageData,
                            addedAt: Date(), lastReadAt: nil, position: nil,
                            spineCount: epub.chapters.count)
            books.insert(book, at: 0)
            save()
        } catch {
            importError = "无法导入:\(error.localizedDescription)"
        }
    }

    func remove(_ book: Book) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docs.appendingPathComponent(book.fileName))
        books.removeAll { $0.id == book.id }
        save()
    }

    func touch(_ bookID: UUID) {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[i].lastReadAt = Date()
        save()
    }

    func updatePosition(bookID: UUID, position: FolioPosition) {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[i].position = position
        books[i].lastReadAt = Date()
        save()
    }
}
