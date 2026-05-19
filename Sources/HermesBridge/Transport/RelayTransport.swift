import Foundation
import HermesCore

/// Cloud-relay transport for when the iPhone and Mac are not on the same LAN.
///
/// Protocol: the relay is a stateless WebSocket multiplexer keyed by a `routing` token.
/// Both Mac and iPhone connect to the same `routing` and the relay copies frames between them.
/// Same `Message` envelope as the LAN transport — only the connection URL and headers differ.
///
/// This is a thin wrapper around `WebSocketTransport`, plus a relay-specific URL builder.
/// We keep it as a separate type so the SessionManager can present "via relay" vs "via LAN" to the user.
public final class RelayTransport: Transport, @unchecked Sendable {
    public let name = "relay"

    private let inner: WebSocketTransport

    public var state: TransportState { inner.state }
    public var stateStream: AsyncStream<TransportState> { inner.stateStream }
    public var messageStream: AsyncStream<Message> { inner.messageStream }

    /// - Parameters:
    ///   - baseURL: e.g. `wss://relay.hermes-webui.dev`
    ///   - routingToken: a shared, randomly-generated token (issued during pairing) — identifies the iPhone/Mac pair.
    ///   - deviceToken: this device's auth token (also from pairing).
    public init(baseURL: URL, routingToken: String, deviceToken: String) {
        let url = baseURL.appendingPathComponent("v1/bridge").appendingPathComponent(routingToken)
        self.inner = WebSocketTransport(url: url, token: deviceToken)
    }

    public func connect() async throws { try await inner.connect() }
    public func send(_ message: Message) async throws { try await inner.send(message) }
    public func disconnect() async { await inner.disconnect() }
}
