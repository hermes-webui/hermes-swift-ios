import Foundation
import os
import AVFoundation
import WebKit

/// Owns WKWebView's navigation lifecycle:
///   1. Pinning — if the active endpoint has `leafCertFingerprint`, reject TLS handshakes that
///      don't match.
///   2. Scheme allowlist — only http/https loads are permitted (no file://, no app schemes).
///   3. Failure mapping — translates NSURLError codes into actionable messages (mirrors patterns
///      used by the desktop client.
public final class NavigationDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {

    public var pinner: FingerprintPinner?
    public var reconnectGeneration: Int = 0

    public init(pinner: FingerprintPinner? = nil) {
        self.pinner = pinner
    }

    public func webView(_ webView: WKWebView,
                        didReceive challenge: URLAuthenticationChallenge,
                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // No pinner configured (e.g. plain-HTTP dev endpoint) — fall through to the system trust store.
        guard let pinner else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if pinner.matches(serverTrust: trust) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            Loggers.webView.error("TLS pinning mismatch on \(challenge.protectionSpace.host, privacy: .public) — aborting.")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let scheme = navigationAction.request.url?.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleFailure(error)
    }

    @available(iOS 15.0, *)
    public func webView(_ webView: WKWebView,
                        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                        initiatedByFrame frame: WKFrameInfo,
                        type: WKMediaCaptureType,
                        decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        switch type {
        case .microphone:
            requestAccess(for: .audio, decisionHandler: decisionHandler)
        case .camera:
            requestAccess(for: .video, decisionHandler: decisionHandler)
        case .cameraAndMicrophone:
            requestCombinedAccess(decisionHandler: decisionHandler)
        @unknown default:
            decisionHandler(.deny)
        }
    }

    private func handleFailure(_ error: Error) {
        let ns = error as NSError
        if ns.code == NSURLErrorCancelled { return }   // -999, ignore (includes pinning aborts)

        let hint: String
        switch ns.code {
        case -1022: hint = "Blocked by App Transport Security. Add NSAllowsArbitraryLoadsInWebContent for dev, or use HTTPS."
        case -1004: hint = "Server refused the connection. Is webui running and reachable from this device?"
        case -1003: hint = "Hostname could not be resolved."
        case -1001: hint = "Request timed out."
        case -1202: hint = "TLS evaluation failed (cert untrusted or mismatched)."
        default:    hint = ns.localizedDescription
        }
        Loggers.webView.error("Navigation failed (\(ns.code, privacy: .public)): \(hint, privacy: .public)")
        // TODO: surface to user via an error overlay; logging only for now.
    }

    public func webView(_ webView: WKWebView,
                        didFailProvisionalNavigation navigation: WKNavigation!,
                        withError error: Error) {
        handleFailure(error)
    }

    @available(iOS 15.0, *)
    private func requestAccess(for mediaType: AVMediaType,
                               decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            decisionHandler(.grant)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                decisionHandler(granted ? .grant : .deny)
            }
        default:
            decisionHandler(.deny)
        }
    }

    @available(iOS 15.0, *)
    private func requestCombinedAccess(decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        requestAccess(for: .video) { [weak self] cameraDecision in
            guard let self, cameraDecision == .grant else {
                decisionHandler(.deny)
                return
            }
            self.requestAccess(for: .audio, decisionHandler: decisionHandler)
        }
    }

}
