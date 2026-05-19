import Foundation
import CryptoKit
import HermesCore

/// `URLSessionDelegate` that enforces SHA-256 fingerprint pinning on the server's TLS certificate.
///
/// During pairing, the Mac includes its TLS leaf-cert SHA-256 fingerprint in the QR payload
/// (`PairingPayload.fingerprint`). When the iPhone later opens `wss://` to the same Mac, this
/// delegate verifies that the server presents the same cert. A mismatch terminates the handshake
/// with `cancelAuthenticationChallenge` — i.e. someone has either swapped in their own server on
/// the same `host:port` or the Mac legitimately rotated its keypair. In the latter case the user
/// must re-pair.
///
/// Format: `fingerprint` is the **lowercase hex** SHA-256 of the leaf cert's DER bytes,
/// with no colons. Example: `"a1b2c3...ef"` (64 hex chars).
public final class FingerprintPinner: NSObject, URLSessionDelegate, @unchecked Sendable {

    public let expectedFingerprint: String

    /// When `true`, log a warning but don't reject mismatches. Use only for dev — never in production.
    public let auditOnly: Bool

    public init(expectedFingerprint: String, auditOnly: Bool = false) {
        self.expectedFingerprint = expectedFingerprint.lowercased()
        self.auditOnly = auditOnly
    }

    public func urlSession(_ session: URLSession,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let leaf = Self.leafCertificate(in: trust) else {
            Loggers.transport.error("Pinning: no leaf cert in challenge")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let actual = Self.fingerprint(of: leaf)
        if actual == expectedFingerprint {
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }

        Loggers.transport.error("Pinning mismatch — expected \(self.expectedFingerprint, privacy: .public), got \(actual, privacy: .public)")
        if auditOnly {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    /// Compute the SHA-256 fingerprint of a DER-encoded certificate. Public so the Mac side
    /// (or tests) can compute the same value from the same bytes.
    public static func fingerprint(ofDER data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func fingerprint(of certificate: SecCertificate) -> String {
        let data = SecCertificateCopyData(certificate) as Data
        return fingerprint(ofDER: data)
    }

    private static func leafCertificate(in trust: SecTrust) -> SecCertificate? {
        if #available(iOS 15.0, *) {
            return (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first
        } else {
            #if canImport(Security)
            // SecTrustGetCertificateAtIndex is deprecated but the only pre-iOS 15 option.
            return SecTrustGetCertificateAtIndex(trust, 0)
            #else
            return nil
            #endif
        }
    }
}
