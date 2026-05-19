import Foundation

/// Wire format of the QR code displayed by the Mac during pairing.
/// Designed so it can also be delivered via a `hermes://pair?payload=<base64>` deep link.
public struct PairingPayload: Codable, Equatable, Sendable {
    public let version: Int
    public let deviceId: String
    public let displayName: String
    public let host: String
    public let port: Int
    public let fingerprint: String
    public let deviceToken: String
    public let relayRoutingToken: String?

    public init(version: Int = 1, deviceId: String, displayName: String, host: String, port: Int,
                fingerprint: String, deviceToken: String, relayRoutingToken: String? = nil) {
        self.version = version
        self.deviceId = deviceId
        self.displayName = displayName
        self.host = host
        self.port = port
        self.fingerprint = fingerprint
        self.deviceToken = deviceToken
        self.relayRoutingToken = relayRoutingToken
    }
}

public enum QRPairing {

    public enum Error: Swift.Error, Equatable {
        case invalidEncoding
        case unsupportedVersion(Int)
    }

    /// Encode a payload into the string that the Mac displays as a QR.
    /// Format: `hermes:pair:v1:<base64url-of-json>`
    public static func encode(_ payload: PairingPayload) throws -> String {
        let json = try JSONEncoder().encode(payload)
        let b64 = json.base64URLEncodedString()
        return "hermes:pair:v\(payload.version):\(b64)"
    }

    /// Decode either the raw QR string or a `hermes://pair?payload=...` deep link.
    public static func decode(_ raw: String) throws -> PairingPayload {
        let candidate: String
        if raw.hasPrefix("hermes://pair") {
            guard let comps = URLComponents(string: raw),
                  let payload = comps.queryItems?.first(where: { $0.name == "payload" })?.value else {
                throw Error.invalidEncoding
            }
            candidate = "hermes:pair:v1:\(payload)"
        } else {
            candidate = raw
        }

        let parts = candidate.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false)
        guard parts.count == 4, parts[0] == "hermes", parts[1] == "pair" else { throw Error.invalidEncoding }
        let versionTag = String(parts[2])
        guard versionTag.hasPrefix("v"), let version = Int(versionTag.dropFirst()) else { throw Error.invalidEncoding }
        guard version == 1 else { throw Error.unsupportedVersion(version) }
        guard let data = Data(base64URLEncoded: String(parts[3])) else { throw Error.invalidEncoding }
        return try JSONDecoder().decode(PairingPayload.self, from: data)
    }
}

extension Data {
    fileprivate func base64URLEncodedString() -> String {
        return self.base64EncodedString()
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
