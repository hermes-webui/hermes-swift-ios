import Foundation
import WebKit
import HermesCore

/// Mirrors the failure-handling patterns from hermes-swift-mac's BrowserWindowController.
/// CRITICAL: implement BOTH didFailProvisionalNavigation AND didFail — missing either causes silent failures.
public final class NavigationDelegate: NSObject, WKNavigationDelegate {

    public override init() { super.init() }

    public func webView(_ webView: WKWebView,
                        didFailProvisionalNavigation navigation: WKNavigation!,
                        withError error: Error) {
        handleFailure(error, on: webView)
    }

    public func webView(_ webView: WKWebView,
                        didFail navigation: WKNavigation!,
                        withError error: Error) {
        handleFailure(error, on: webView)
    }

    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Only allow http/https/ws/wss navigation. Reject file://, custom schemes, etc.
        guard let scheme = navigationAction.request.url?.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    private func handleFailure(_ error: Error, on webView: WKWebView) {
        let ns = error as NSError
        if ns.code == NSURLErrorCancelled { return }   // -999, ignore

        let hint: String
        switch ns.code {
        case -1022: hint = "Blocked by App Transport Security. Add NSAllowsArbitraryLoadsInWebContent (dev only) or use HTTPS."
        case -1004: hint = "Server refused the connection. Is hermes-webui running and reachable from this device?"
        case -1003: hint = "Hostname could not be resolved."
        case -1001: hint = "Request timed out."
        default:    hint = ns.localizedDescription
        }
        Loggers.webView.error("Navigation failed (\(ns.code, privacy: .public)): \(hint, privacy: .public)")
        // TODO: surface to user via an error overlay view; for now log only.
    }
}
