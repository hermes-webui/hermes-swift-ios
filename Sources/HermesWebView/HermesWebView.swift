import SwiftUI
import WebKit
import HermesCore

/// SwiftUI wrapper around the configured Hermes WKWebView.
public struct HermesWebView: UIViewRepresentable {
    public let url: URL
    public let bridge: JSBridge

    public init(url: URL, bridge: JSBridge) {
        self.url = url
        self.bridge = bridge
    }

    public func makeCoordinator() -> NavigationDelegate {
        NavigationDelegate()
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WebViewConfiguration.make(bridge: bridge)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }
}
