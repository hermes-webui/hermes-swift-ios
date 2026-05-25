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
    /// Enables the native JS bridge for this endpoint (`window.hermes.invoke(...)`).
    /// Keep disabled for generic web apps that do not need iPhone-native APIs.
    public let nativeBridgeEnabled: Bool

    public let addedAt: Date

    public init(url: URL,
                displayName: String,
                leafCertFingerprint: String? = nil,
                nativeBridgeEnabled: Bool = true,
                addedAt: Date = .init()) {
        self.url = url
        self.displayName = displayName
        self.leafCertFingerprint = leafCertFingerprint?.lowercased()
        self.nativeBridgeEnabled = nativeBridgeEnabled
        self.addedAt = addedAt
    }

    private enum CodingKeys: String, CodingKey {
        case url
        case displayName
        case leafCertFingerprint
        case nativeBridgeEnabled
        case addedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decode(URL.self, forKey: .url)
        displayName = try c.decode(String.self, forKey: .displayName)
        leafCertFingerprint = try c.decodeIfPresent(String.self, forKey: .leafCertFingerprint)?.lowercased()
        nativeBridgeEnabled = try c.decodeIfPresent(Bool.self, forKey: .nativeBridgeEnabled) ?? true
        addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? .init()
    }
}
