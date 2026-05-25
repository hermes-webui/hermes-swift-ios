import Foundation

/// Encodes a `HermesEndpoint` payload for QR display / deep-link share.
///
/// Wire format: `hermes:agent:v1:<base64url(JSON)>` (and the equivalent
/// `hermes://agent?payload=<base64url(JSON)>` deep link).
///
/// A webui machine can render this QR to share its endpoint with the phone.
/// The iPhone scans, decodes, and writes the result to
/// `EndpointStore`. Pinning material (`leafCertFingerprint`) is optional but recommended for
/// any TLS-terminated deployment.
public enum EndpointQR {

    public enum Error: Swift.Error, Equatable {
        case invalidEncoding
        case unsupportedVersion(Int)
    }

    public struct Payload: Codable, Equatable, Sendable {
        public let url: String
        public let displayName: String
        public let leafCertFingerprint: String?

        public init(url: String,
                    displayName: String,
                    leafCertFingerprint: String? = nil) {
            self.url = url
            self.displayName = displayName
            self.leafCertFingerprint = leafCertFingerprint
        }
    }

    public static func encode(_ payload: Payload) throws -> String {
        let data = try JSONEncoder().encode(payload)
        return "hermes:agent:v1:\(data.base64URLEncodedString())"
    }

    public static func decode(_ raw: String) throws -> Payload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String
        if trimmed.hasPrefix("hermes://agent") {
            guard let comps = URLComponents(string: trimmed),
                  let payload = comps.queryItems?.first(where: { $0.name == "payload" })?.value else {
                throw Error.invalidEncoding
            }
            candidate = "hermes:agent:v1:\(payload)"
        } else {
            candidate = trimmed
        }

        let parts = candidate.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false)
        guard parts.count == 4, parts[0] == "hermes", parts[1] == "agent" else { throw Error.invalidEncoding }
        let versionTag = String(parts[2])
        guard versionTag.hasPrefix("v"), let version = Int(versionTag.dropFirst()) else { throw Error.invalidEncoding }
        guard version == 1 else { throw Error.unsupportedVersion(version) }
        guard let data = Data(base64URLEncoded: String(parts[3])) else { throw Error.invalidEncoding }
        return try JSONDecoder().decode(Payload.self, from: data)
    }

    public static func endpoint(from payload: Payload) throws -> HermesEndpoint {
        guard let url = URL(string: payload.url) else { throw Error.invalidEncoding }
        return HermesEndpoint(
            url: url,
            displayName: payload.displayName,
            leafCertFingerprint: payload.leafCertFingerprint
        )
    }
}

extension Data {
    fileprivate func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    fileprivate init?(base64URLEncoded s: String) {
        var b64 = s
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64.append("=") }
        guard let d = Data(base64Encoded: b64) else { return nil }
        self = d
    }
}
