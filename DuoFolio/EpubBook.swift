import Foundation

/// EPUB 解析:container → OPF → spine → 章节列表 + 资源内联。
/// 输出一份"自包含 HTML"(CSS/图片以 data URI 内联),喂给 WKWebView 分页。
struct EpubBook {
    struct Chapter: Identifiable, Hashable {
        let id: Int          // spine 序号
        let title: String
        let href: String     // opf 内路径
    }

    let title: String
    let author: String
    let coverImageData: Data?
    let chapters: [Chapter]
    let archive: MiniZip.Archive
    /// opf 所在目录(解析相对路径基准)
    let opfDir: String

    /// 全书扁平 HTML(章节间用分页符)
    func flatHTML(chapterIndex: Int) -> String? {
        guard chapterIndex >= 0 && chapterIndex < chapters.count else { return nil }
        let ch = chapters[chapterIndex]
        guard var html = readString(ch.href) else { return nil }
        html = inlineResources(html: html, baseURL: opfDir.isEmpty ? "" : opfDir + "/")
        return html
    }

    func readString(_ path: String) -> String? {
        let key = resolve(path)
        guard let d = archive.read(key) ?? archive.read((opfDir as NSString).appendingPathComponent(path)) else { return nil }
        return String(data: d, encoding: .utf8)
    }

    func readData(_ path: String) -> Data? {
        archive.read(resolve(path))
    }

    /// 相对 opfDir 归一化
    private func resolve(_ path: String) -> String {
        if opfDir.isEmpty { return path }
        if path.hasPrefix(opfDir + "/") { return path }
        return opfDir + "/" + path
    }

    /// 把 html 里的 <img src>、<link href=stylesheet> 内联为 data URI / <style>
    func inlineResources(html: String, baseURL: String) -> String {
        var out = html
        // 1. <link rel=stylesheet href="...">
        if let regex = try? NSRegularExpression(pattern: "<link[^>]*rel=[\"']stylesheet[\"'][^>]*>", options: [.caseInsensitive]) {
            let ns = out as NSString
            let matches = regex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                let tag = ns.substring(with: m.range)
                if let href = firstAttribute("href", in: tag) {
                    let path = normalizeRel(href, base: baseURL)
                    if let css = readString(path) {
                        // css 内的 url(...) 也要内联
                        let inlined = inlineCSSUrls(css: css, baseURL: dirName(of: path))
                        out = (out as NSString).replacingCharacters(in: m.range, with: "<style>\(inlined)</style>")
                    } else {
                        out = (out as NSString).replacingCharacters(in: m.range, with: "")
                    }
                }
            }
        }
        // 2. <style> 内 url(...)
        // 3. <img src>
        if let regex = try? NSRegularExpression(pattern: "<img[^>]*>", options: [.caseInsensitive]) {
            let ns = out as NSString
            let matches = regex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                let tag = ns.substring(with: m.range)
                guard let src = firstAttribute("src", in: tag) else { continue }
                let path = normalizeRel(src, base: baseURL)
                if let d = readData(path) {
                    let mime = mimeFor(path)
                    let b64 = d.base64EncodedString()
                    let newTag = tag.replacingOccurrences(of: src, with: "data:\(mime);base64,\(b64)")
                    out = (out as NSString).replacingCharacters(in: m.range, with: newTag)
                }
            }
        }
        // 4. svg <image href>
        if let regex = try? NSRegularExpression(pattern: "<image[^>]*>", options: [.caseInsensitive]) {
            let ns = out as NSString
            let matches = regex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                let tag = ns.substring(with: m.range)
                if let href = firstAttribute("href", in: tag) ?? firstAttribute("xlink:href", in: tag) {
                    if href.hasPrefix("data:") { continue }
                    let path = normalizeRel(href, base: baseURL)
                    if let d = readData(path) {
                        let mime = mimeFor(path)
                        let b64 = d.base64EncodedString()
                        let newTag = tag.replacingOccurrences(of: href, with: "data:\(mime);base64,\(b64)")
                        out = (out as NSString).replacingCharacters(in: m.range, with: newTag)
                    }
                }
            }
        }
        return out
    }

    private func inlineCSSUrls(css: String, baseURL: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "url\\(([^)]+)\\)", options: [.caseInsensitive]) else { return css }
        let ns = css as NSString
        var out = css
        let matches = regex.matches(in: css, range: NSRange(location: 0, length: ns.length)).reversed()
        for m in matches {
            var target = ns.substring(with: m.range(at: 1))
            target = target.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            guard !target.hasPrefix("data:") else { continue }
            let path = normalizeRel(target, base: baseURL)
            if let d = readData(path) {
                let uri = "data:\(mimeFor(path));base64,\(d.base64EncodedString())"
                out = (out as NSString).replacingCharacters(in: m.range(at: 1), with: uri)
            }
        }
        return out
    }

    private func normalizeRel(_ path: String, base: String) -> String {
        guard !path.hasPrefix("/") else { return String(path.dropFirst()) }
        let combined = base + path
        // 处理 ../
        var parts: [String] = []
        for seg in combined.split(separator: "/") {
            if seg == ".." { parts.removeLast() }
            else if seg != "." { parts.append(String(seg)) }
        }
        return parts.joined(separator: "/")
    }

    private func dirName(of path: String) -> String {
        guard let r = path.range(of: "/", options: .backwards) else { return "" }
        return String(path[..<r.lowerBound]) + "/"
    }

    private func firstAttribute(_ name: String, in tag: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\(name)\\s*=\\s*[\"']([^\"']*)[\"']", options: [.caseInsensitive]) else { return nil }
        let ns = tag as NSString
        guard let m = regex.firstMatch(in: tag, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    private func mimeFor(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "css": return "text/css"
        default: return "application/octet-stream"
        }
    }

    // MARK: - Parse

    static func parse(data: Data) throws -> EpubBook {
        let zip = try MiniZip.open(data: data)

        // 1. container.xml → opf 路径
        let containerXML = zip.read("META-INF/container.xml")
            .flatMap { String(data: $0, encoding: .utf8) }
        var opfPath = "content.opf"
        if let cx = containerXML,
           let r = cx.range(of: "full-path=\"") {
            let rest = cx[r.upperBound...]
            if let e = rest.range(of: "\"") {
                opfPath = String(rest[..<e.lowerBound])
            }
        }

        // 2. OPF 解析
        guard let opfData = zip.read(opfPath), let opf = String(data: opfData, encoding: .utf8) else {
            throw NSError(domain: "Epub", code: 1, userInfo: [NSLocalizedDescriptionKey: "OPF not found: \(opfPath)"])
        }
        let opfDir: String = {
            if let r = opfPath.range(of: "/", options: .backwards) {
                return String(opfPath[..<r.lowerBound])
            }
            return ""
        }()

        let title = extractTag("dc:title", from: opf) ?? extractTag("title", from: opf) ?? "未命名"
        let author = extractTag("dc:creator", from: opf) ?? extractTag("creator", from: opf) ?? ""

        // manifest: id → href
        var manifest: [String: String] = [:]
        if let regex = try? NSRegularExpression(pattern: "<item\\b[^>]*>", options: [.caseInsensitive]) {
            let ns = opf as NSString
            for m in regex.matches(in: opf, range: NSRange(location: 0, length: ns.length)) {
                let tag = ns.substring(with: m.range)
                let id = attr("id", tag)
                let href = attr("href", tag)
                if let id, let href { manifest[id] = href }
            }
        }

        // spine → 章节序列
        var chapters: [Chapter] = []
        if let regex = try? NSRegularExpression(pattern: "<itemref\\b[^>]*>", options: [.caseInsensitive]) {
            let ns = opf as NSString
            var idx = 0
            for m in regex.matches(in: opf, range: NSRange(location: 0, length: ns.length)) {
                let tag = ns.substring(with: m.range)
                guard let idref = attr("idref", tag), let href = manifest[idref] else { continue }
                let full = href.hasPrefix("/") ? String(href.dropFirst()) : (opfDir.isEmpty ? href : opfDir + "/" + href)
                chapters.append(Chapter(id: idx, title: "", href: full))
                idx += 1
            }
        }

        // 3. 封面:cover-image / meta name=cover / manifest properties=cover-image
        var coverData: Data?
        if let regex = try? NSRegularExpression(pattern: "<meta\\b[^>]*name=[\"']cover[\"'][^>]*>", options: [.caseInsensitive]) {
            let ns = opf as NSString
            if let m = regex.firstMatch(in: opf, range: NSRange(location: 0, length: ns.length)) {
                if let cid = attr("content", ns.substring(with: m.range)), let href = manifest[cid] {
                    let full = opfDir.isEmpty ? href : opfDir + "/" + href
                    coverData = zip.read(full)
                }
            }
        }
        if coverData == nil {
            for (_, href) in manifest where href.lowercased().contains("cover") {
                let ext = (href as NSString).pathExtension.lowercased()
                if ["jpg", "jpeg", "png"].contains(ext) {
                    let full = opfDir.isEmpty ? href : opfDir + "/" + href
                    if let d = zip.read(full) { coverData = d; break }
                }
            }
        }

        // 4. TOC 章节标题:nav.xhtml(epub3)或 toc.ncx(epub2),按 href 匹配
        let titles = resolveChapterTitles(zip: zip, opfDir: opfDir, manifest: manifest, chapters: chapters)

        return EpubBook(title: title, author: author, coverImageData: coverData,
                        chapters: chapters, archive: zip, opfDir: opfDir)
        .withTitles(titles)
    }

    func withTitles(_ titles: [Int: String]) -> EpubBook {
        EpubBook(title: title, author: author, coverImageData: coverImageData,
                 chapters: chapters.map { ch in
                     var c = ch
                     c = Chapter(id: c.id, title: titles[c.id] ?? "", href: c.href)
                     return c
                 },
                 archive: archive, opfDir: opfDir)
    }

    private static func resolveChapterTitles(zip: MiniZip.Archive, opfDir: String,
                                             manifest: [String: String],
                                             chapters: [Chapter]) -> [Int: String] {
        var result: [Int: String] = [:]
        // href → chapter index
        var hrefIndex: [String: Int] = [:]
        for ch in chapters {
            hrefIndex[ch.href] = ch.id
            if let r = ch.href.range(of: "/", options: .backwards) {
                hrefIndex[String(ch.href[r.upperBound...])] = ch.id
            }
        }
        func addTitle(_ hrefRaw: String, _ t: String) {
            let href = hrefRaw.split(separator: "#").first.map(String.init) ?? hrefRaw
            let full = href.hasPrefix("/") ? String(href.dropFirst()) : (opfDir.isEmpty ? href : opfDir + "/" + href)
            if let idx = hrefIndex[full] ?? hrefIndex[href] {
                if result[idx] == nil { result[idx] = t }
            }
        }
        // epub3 nav
        if let navHref = manifest.values.first(where: { $0.lowercased().contains("nav") && $0.hasSuffix("xhtml") }) {
            let full = opfDir.isEmpty ? navHref : opfDir + "/" + navHref
            if let d = zip.read(full), let s = String(data: d, encoding: .utf8) {
                parseNavAnchors(s).forEach { addTitle($0.0, $0.1) }
            }
        }
        // epub2 ncx
        if let ncxHref = manifest.values.first(where: { $0.hasSuffix("ncx") }) {
            let full = opfDir.isEmpty ? ncxHref : opfDir + "/" + ncxHref
            if let d = zip.read(full), let s = String(data: d, encoding: .utf8) {
                parseNcxPoints(s).forEach { addTitle($0.0, $0.1) }
            }
        }
        return result
    }

    private static func parseNavAnchors(_ html: String) -> [(String, String)] {
        var out: [(String, String)] = []
        guard let regex = try? NSRegularExpression(pattern: "<a\\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>",
                                                   options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return out }
        let ns = html as NSString
        for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let href = ns.substring(with: m.range(at: 1))
            var text = ns.substring(with: m.range(at: 2))
            text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { out.append((href, text)) }
        }
        return out
    }

    private static func parseNcxPoints(_ xml: String) -> [(String, String)] {
        var out: [(String, String)] = []
        guard let regex = try? NSRegularExpression(pattern: "<navPoint.*?</navPoint>",
                                                   options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return out }
        let ns = xml as NSString
        let contentRe = try? NSRegularExpression(pattern: "<content\\b[^>]*src=[\"']([^\"']+)[\"']", options: [.caseInsensitive])
        let labelRe = try? NSRegularExpression(pattern: "<text[^>]*>(.*?)</text>", options: [.caseInsensitive, .dotMatchesLineSeparators])
        for m in regex.matches(in: xml, range: NSRange(location: 0, length: ns.length)) {
            let block = ns.substring(with: m.range)
            var label = ""
            if let lr = labelRe, let lm = lr.firstMatch(in: block, range: NSRange(location: 0, length: (block as NSString).length)) {
                label = (block as NSString).substring(with: lm.range(at: 1))
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let cr = contentRe, let cm = cr.firstMatch(in: block, range: NSRange(location: 0, length: (block as NSString).length)) {
                let src = (block as NSString).substring(with: cm.range(at: 1))
                if !label.isEmpty { out.append((src, label)) }
            }
        }
        return out
    }

    private static func extractTag(_ tag: String, from xml: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<\(tag)\\b[^>]*>(.*?)</\(tag)>",
                                                   options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
        let ns = xml as NSString
        guard let m = regex.firstMatch(in: xml, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func attr(_ name: String, _ tag: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\(name)\\s*=\\s*[\"']([^\"']*)[\"']", options: [.caseInsensitive]) else { return nil }
        let ns = tag as NSString
        guard let m = regex.firstMatch(in: tag, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range(at: 1))
    }
}
