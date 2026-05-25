import SwiftUI
import WebKit
import HermesCore

/// SwiftUI wrapper that hosts the configured webui inside a `WKWebView`.
public struct HermesWebView: UIViewRepresentable {
    public let endpoint: HermesEndpoint
    public let bridge: JSBridge

    public init(endpoint: HermesEndpoint, bridge: JSBridge) {
        self.endpoint = endpoint
        self.bridge = bridge
    }

    public func makeCoordinator() -> NavigationDelegate {
        NavigationDelegate(pinner: endpoint.leafCertFingerprint.map(FingerprintPinner.init))
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WebViewConfiguration.make(bridge: bridge)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        bridge.attach(to: webView)
        webView.load(makeRequest())
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // Reload when the endpoint URL changes (e.g. user switched active endpoint in Settings).
        if uiView.url != endpoint.url {
            context.coordinator.pinner = endpoint.leafCertFingerprint.map(FingerprintPinner.init)
            uiView.load(makeRequest())
        }
    }

    private func makeRequest() -> URLRequest {
        var request = URLRequest(url: endpoint.url)
        if let token = endpoint.bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
