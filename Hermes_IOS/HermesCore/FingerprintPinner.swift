import Foundation
import CryptoKit

/// SHA-256 leaf-cert pinning used by `HermesWebView`'s navigation delegate.
///
/// The expected fingerprint comes from the QR-shared `HermesEndpoint.leafCertFingerprint`.
/// On every TLS handshake to the pinned host, the delegate compares the server's leaf cert
/// (DER bytes, lowercase hex SHA-256) against the stored value and rejects mismatches.
public final class FingerprintPinner: Sendable {
    public let expectedFingerprint: String

    public init(expectedFingerprint: String) {
        self.expectedFingerprint = expectedFingerprint.lowercased()
    }

    /// Returns `true` if the trust chain's leaf matches the pinned fingerprint.
    public func matches(serverTrust trust: SecTrust) -> Bool {
        guard let leaf = Self.leafCertificate(in: trust) else { return false }
        return Self.fingerprint(of: leaf) == expectedFingerprint
    }

    public static func fingerprint(ofDER data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func fingerprint(of certificate: SecCertificate) -> String {
        fingerprint(ofDER: SecCertificateCopyData(certificate) as Data)
    }

    private static func leafCertificate(in trust: SecTrust) -> SecCertificate? {
        if #available(iOS 15.0, *) {
            return (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first
        } else {
            return SecTrustGetCertificateAtIndex(trust, 0)
        }
    }
}
