import Foundation

/// A configured webui endpoint — the URL the WKWebView will load + optional integrity material.
///
/// The iPhone reaches `url` through the user's existing Tailscale connectivity.
public struct HermesEndpoint: Codable, Hashable, Sendable, Identifiable {
    public var id: String { url.absoluteString }

    /// e.g. `https://webui.tailnet.ts.net` or `http://webui.local:8787`
    public let url: URL

    /// Human-readable label shown in Settings ("Home", "Studio", "Tailscale").
    public let displayName: String

    /// Lowercase-hex SHA-256 of the agent's TLS leaf certificate (DER bytes). When present, the
    /// WKWebView's WKNavigationDelegate enforces pinning — connections to the same `url.host`
    /// presenting a different cert are rejected. Set this for any non-self-signed deployment you care
    /// about defending; leave nil for plain `http://` localhost dev.
    public let leafCertFingerprint: String?

    public let addedAt: Date

    public init(url: URL,
                displayName: String,
                leafCertFingerprint: String? = nil,
                addedAt: Date = .init()) {
        self.url = url
        self.displayName = displayName
        self.leafCertFingerprint = leafCertFingerprint?.lowercased()
        self.addedAt = addedAt
    }
}
