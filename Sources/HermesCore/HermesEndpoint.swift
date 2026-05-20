import Foundation

/// A configured Hermes Agent endpoint — the URL the WKWebView will load + optional integrity material.
///
/// The Mac doesn't have to be running. The iPhone reaches `url` over whatever network path the user
/// already has (Tailscale, public domain, local LAN, etc.). This app inherits the user's existing
/// reachability rather than building its own.
public struct HermesEndpoint: Codable, Hashable, Sendable, Identifiable {
    public var id: String { url.absoluteString }

    /// e.g. `https://hermes.tailnet.ts.net` or `http://hermes.local:8787`
    public let url: URL

    /// Human-readable label shown in Settings ("Home", "Studio", "Tailscale").
    public let displayName: String

    /// Lowercase-hex SHA-256 of the agent's TLS leaf certificate (DER bytes). When present, the
    /// WKWebView's WKNavigationDelegate enforces pinning — connections to the same `url.host`
    /// presenting a different cert are rejected. Set this for any non-self-signed deployment you care
    /// about defending; leave nil for plain `http://` localhost dev.
    public let leafCertFingerprint: String?

    /// Optional bearer/auth header injected on each request to `url`. Stored in the Keychain via
    /// `EndpointStore`. Useful when the agent is gated by a static token.
    public let bearerToken: String?

    public let addedAt: Date

    public init(url: URL,
                displayName: String,
                leafCertFingerprint: String? = nil,
                bearerToken: String? = nil,
                addedAt: Date = .init()) {
        self.url = url
        self.displayName = displayName
        self.leafCertFingerprint = leafCertFingerprint?.lowercased()
        self.bearerToken = bearerToken
        self.addedAt = addedAt
    }
}
