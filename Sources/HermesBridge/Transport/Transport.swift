import Foundation

/// Abstract transport so the `BridgeClient` doesn't know whether it's on LAN or relay.
/// Add a new transport by conforming — do not branch inside the client.
public protocol Transport: AnyObject, Sendable {
    /// Human-readable identifier for logging.
    var name: String { get }

    var state: TransportState { get }
    var stateStream: AsyncStream<TransportState> { get }

    /// Stream of decoded messages from the peer.
    var messageStream: AsyncStream<Message> { get }

    func connect() async throws
    func send(_ message: Message) async throws
    func disconnect() async
}

public enum TransportState: Sendable, Equatable {
    case idle
    case connecting
    case connected
    case disconnected(reason: String?)
}

public enum TransportError: Error, Sendable {
    case notConnected
    case encodingFailed
    case decodingFailed
    case authenticationFailed
    case unsupportedVersion
    case underlying(String)
}
