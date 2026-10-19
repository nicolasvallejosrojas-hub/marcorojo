import SwiftUI
import WebKit
import Photos

@main
struct MarcoRojoApp: App {
    var body: some Scene {
        WindowGroup {
            WebView()
                .ignoresSafeArea()
                .background(Color(white: 0.04).ignoresSafeArea())
                .preferredColorScheme(.dark)
        }
    }
}

// The whole UI lives in marco-rojo.html; Swift only hosts it and saves to Photos.
struct WebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.addScriptMessageHandler(PhotoSaver(), contentWorld: .page, name: "save")
        config.userContentController.add(SettingsOpener(), name: "openSettings")
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        // The page pads itself with env(safe-area-inset-*).
        web.scrollView.contentInsetAdjustmentBehavior = .never
        let url = Bundle.main.url(forResource: "marco-rojo", withExtension: "html")!
        web.loadFileURL(url, allowingReadAccessTo: url)
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}
}

// JS: await webkit.messageHandlers.save.postMessage(base64Jpeg)
final class PhotoSaver: NSObject, WKScriptMessageHandlerWithReply {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard let base64 = message.body as? String, let data = Data(base64Encoded: base64) else {
            return replyHandler(nil, "imagen inválida")
        }
        // Ask for add-only access explicitly: performChanges alone asks for full read/write
        // access, which iOS denies (PHPhotosErrorDomain 3311) without NSPhotoLibraryUsageDescription.
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                return DispatchQueue.main.async { replyHandler(nil, "denied") }
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }) { ok, error in
                DispatchQueue.main.async {
                    ok ? replyHandler(true, nil) : replyHandler(nil, error?.localizedDescription ?? "no se pudo guardar")
                }
            }
        }
    }
}

// JS: webkit.messageHandlers.openSettings.postMessage(null)
final class SettingsOpener: NSObject, WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}
