import Foundation

/// Versioned envelope for every message on the wire (LAN WebSocket or cloud Relay).
/// Bump `BridgeProtocol.currentVersion` and `docs/BRIDGE_PROTOCOL.md` together when the contract changes.
public enum BridgeProtocol {
    public static let currentVersion = 1
    public static let supportedVersions: ClosedRange<Int> = 1...1
}

public struct Message: Codable, Sendable, Equatable {
    public let id: String
    public let protocolVersion: Int
    public let kind: Kind
    public let payload: Payload

    public enum Kind: String, Codable, Sendable {
        /// Client → Server: invoke a typed command on the Mac.
        case commandRequest
        /// Server → Client: result of a previous commandRequest.
        case commandResponse
        /// Server → Client: pushed event (state change, log line, notification).
        case event
        /// Server → Client: capability invocation request (Mac asks iPhone to use camera/etc.).
        case capabilityRequest
        /// Client → Server: response to a capabilityRequest.
        case capabilityResponse
        /// Either direction: liveness probe.
        case ping
        /// Either direction: response to ping.
        case pong
        /// Either direction: graceful protocol/auth error.
        case error
    }

    public enum Payload: Codable, Sendable, Equatable {
        case commandRequest(CommandRequest)
        case commandResponse(CommandResponse)
        case event(EventPayload)
        case capabilityRequest(CapabilityRequest)
        case capabilityResponse(CapabilityResponse)
        case ping
        case pong
        case error(BridgeError)

        private enum CodingKeys: String, CodingKey { case type, data }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .commandRequest(let v):     try c.encode("commandRequest", forKey: .type);     try c.encode(v, forKey: .data)
            case .commandResponse(let v):    try c.encode("commandResponse", forKey: .type);    try c.encode(v, forKey: .data)
            case .event(let v):              try c.encode("event", forKey: .type);              try c.encode(v, forKey: .data)
            case .capabilityRequest(let v):  try c.encode("capabilityRequest", forKey: .type);  try c.encode(v, forKey: .data)
            case .capabilityResponse(let v): try c.encode("capabilityResponse", forKey: .type); try c.encode(v, forKey: .data)
            case .ping:                      try c.encode("ping", forKey: .type)
            case .pong:                      try c.encode("pong", forKey: .type)
            case .error(let v):              try c.encode("error", forKey: .type);              try c.encode(v, forKey: .data)
            }
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)
            switch type {
            case "commandRequest":     self = .commandRequest(try c.decode(CommandRequest.self, forKey: .data))
            case "commandResponse":    self = .commandResponse(try c.decode(CommandResponse.self, forKey: .data))
            case "event":              self = .event(try c.decode(EventPayload.self, forKey: .data))
            case "capabilityRequest":  self = .capabilityRequest(try c.decode(CapabilityRequest.self, forKey: .data))
            case "capabilityResponse": self = .capabilityResponse(try c.decode(CapabilityResponse.self, forKey: .data))
            case "ping":               self = .ping
            case "pong":               self = .pong
            case "error":              self = .error(try c.decode(BridgeError.self, forKey: .data))
            default: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown payload type \(type)")
            }
        }
    }
}

public struct BridgeError: Codable, Sendable, Equatable {
    public let code: String
    public let message: String
    public let inReplyTo: String?

    public init(code: String, message: String, inReplyTo: String? = nil) {
        self.code = code
        self.message = message
        self.inReplyTo = inReplyTo
    }

    public static let unsupportedVersion = "unsupported_version"
    public static let unauthenticated    = "unauthenticated"
    public static let unknownCommand     = "unknown_command"
    public static let unknownCapability  = "unknown_capability"
    public static let invalidPayload     = "invalid_payload"
    public static let internalError      = "internal_error"
}
