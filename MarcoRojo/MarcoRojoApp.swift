import SwiftUI
import WebKit
import Photos

@main
struct MarcoRojoApp: App {
    var body: some Scene {
        WindowGroup {
            WebView()
                .background(Color(white: 0.067).ignoresSafeArea())
                .preferredColorScheme(.dark)
        }
    }
}

// The whole UI lives in marco-rojo.html; Swift only hosts it and saves to Photos.
struct WebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.addScriptMessageHandler(PhotoSaver(), contentWorld: .page, name: "save")
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
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
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }) { ok, error in
            DispatchQueue.main.async {
                ok ? replyHandler(true, nil) : replyHandler(nil, error?.localizedDescription ?? "sin permiso para Fotos")
            }
        }
    }
}
