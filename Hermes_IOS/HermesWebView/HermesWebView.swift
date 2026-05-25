import SwiftUI
import WebKit

/// SwiftUI wrapper that hosts the Hermes Agent dashboard inside a `WKWebView`.
public struct HermesWebView: UIViewRepresentable {
    public let endpoint: HermesEndpoint
    public let bridge: JSBridge
    public let reconnectGeneration: Int

    public init(endpoint: HermesEndpoint, bridge: JSBridge, reconnectGeneration: Int = 0) {
        self.endpoint = endpoint
        self.bridge = bridge
        self.reconnectGeneration = reconnectGeneration
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
        if uiView.url != endpoint.url || context.coordinator.reconnectGeneration != reconnectGeneration {
            context.coordinator.pinner = endpoint.leafCertFingerprint.map(FingerprintPinner.init)
            context.coordinator.reconnectGeneration = reconnectGeneration
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
