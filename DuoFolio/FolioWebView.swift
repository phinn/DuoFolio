import SwiftUI
import WebKit

/// WKWebView 的 SwiftUI 壳:WebView 生命周期由 FolioHostController 持有
struct FolioWebView: UIViewControllerRepresentable {
    let engine: ReaderEngine

    func makeUIViewController(context: Context) -> FolioHostController {
        let vc = FolioHostController()
        vc.attach(engine: engine)
        return vc
    }

    func updateUIViewController(_ vc: FolioHostController, context: Context) {}
}

final class FolioHostController: UIViewController {
    private(set) var bridge: FolioBridge?

    func attach(engine: ReaderEngine) {
        let web = WKWebView(frame: view.bounds, configuration: FolioBridge.makeConfiguration())
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(web)
        let b = FolioBridge(webView: web, engine: engine)
        bridge = b
        engine.bridge = b
        b.load()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        bridge?.teardown()
    }
}
