import Foundation
import Combine
import HermesCore

/// Public API for talking to a paired Mac. Transport-agnostic.
///
/// Typical flow:
/// ```
/// let client = BridgeClient(device: paired, transport: .auto)
/// try await client.connect()
/// let runId = try await client.run(command: .runAgentPrompt, params: ["prompt": .string("hi")])
/// for await event in client.events { ... }
/// ```
@MainActor
public final class BridgeClient: ObservableObject {

    public enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected(via: String) // transport name
        case failed(String)
    }

    public let device: PairedDevice
    @Published public private(set) var status: ConnectionStatus = .disconnected
    @Published public private(set) var lastError: String?

    /// Inbound server-pushed events.
    public var events: AsyncStream<EventPayload> { eventStream }
    private let eventStream: AsyncStream<EventPayload>
    private let eventContinuation: AsyncStream<EventPayload>.Continuation

    /// Inbound capability invocation requests from the Mac.
    public var capabilityRequests: AsyncStream<CapabilityRequest> { capStream }
    private let capStream: AsyncStream<CapabilityRequest>
    private let capContinuation: AsyncStream<CapabilityRequest>.Continuation

    private var transport: Transport?
    private var preference: TransportPreference
    private let relayBaseURL: URL

    /// Pending `commandResponse` waiters keyed by request id.
    private var pendingCommands: [String: CheckedContinuation<CommandResponse, Error>] = [:]

    public init(device: PairedDevice, preference: TransportPreference = .auto, relayBaseURL: URL) {
        self.device = device
        self.preference = preference
        self.relayBaseURL = relayBaseURL

        var ec: AsyncStream<EventPayload>.Continuation!
        self.eventStream = AsyncStream { ec = $0 }
        self.eventContinuation = ec

        var cc: AsyncStream<CapabilityRequest>.Continuation!
        self.capStream = AsyncStream { cc = $0 }
        self.capContinuation = cc
    }

    public func connect() async {
        status = .connecting
        do {
            let t = try await selectTransport()
            self.transport = t
            try await t.connect()
            status = .connected(via: t.name)
            Task { await self.consumeMessages(from: t) }
            Task { await self.observeState(of: t) }
        } catch {
            status = .failed(error.localizedDescription)
            lastError = error.localizedDescription
            Loggers.bridge.error("BridgeClient connect failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func disconnect() async {
        await transport?.disconnect()
        transport = nil
        status = .disconnected
    }

    /// Send a typed command and await the matching response.
    public func run(command: String, params: JSONValue? = nil, timeout: TimeInterval = 30) async throws -> JSONValue? {
        guard let transport else { throw TransportError.notConnected }
        let id = UUID().uuidString
        let message = Message(
            id: id,
            protocolVersion: BridgeProtocol.currentVersion,
            kind: .commandRequest,
            payload: .commandRequest(.init(command: command, params: params))
        )

        return try await withThrowingTaskGroup(of: JSONValue?.self) { group in
            group.addTask {
                try await self.send(message, viaTransport: transport)
                let response = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CommandResponse, Error>) in
                    Task { @MainActor in self.pendingCommands[id] = cont }
                }
                if let err = response.error {
                    throw TransportError.underlying("\(err.code): \(err.message)")
                }
                return response.result
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TransportError.underlying("command timed out after \(timeout)s")
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Reply to a capability request initiated by the Mac.
    public func reply(to request: CapabilityRequest, requestId: String, result: JSONValue? = nil, error: BridgeError? = nil) async throws {
        guard let transport else { throw TransportError.notConnected }
        let msg = Message(
            id: UUID().uuidString,
            protocolVersion: BridgeProtocol.currentVersion,
            kind: .capabilityResponse,
            payload: .capabilityResponse(.init(inReplyTo: requestId, result: result, error: error))
        )
        try await send(msg, viaTransport: transport)
    }

    // MARK: - Internals

    private func send(_ message: Message, viaTransport t: Transport) async throws {
        try await t.send(message)
    }

    private func selectTransport() async throws -> Transport {
        switch preference {
        case .lanOnly:
            return WebSocketTransport(url: lanURL(), token: device.deviceToken)
        case .relayOnly:
            guard let r = device.relayRoutingToken else {
                throw TransportError.underlying("Mac did not enable relay during pairing")
            }
            return RelayTransport(baseURL: relayBaseURL, routingToken: r, deviceToken: device.deviceToken)
        case .auto:
            // TODO(perf): race LAN against relay with a short head-start and pick whichever opens first.
            // For now: try LAN, fall back to relay if a routing token exists.
            let lan = WebSocketTransport(url: lanURL(), token: device.deviceToken)
            do {
                try await lan.connect()
                return lan
            } catch {
                Loggers.bridge.info("LAN transport failed, falling back to relay: \(error.localizedDescription, privacy: .public)")
                guard let r = device.relayRoutingToken else { throw error }
                let relay = RelayTransport(baseURL: relayBaseURL, routingToken: r, deviceToken: device.deviceToken)
                return relay
            }
        }
    }

    private func lanURL() -> URL {
        // ws://<host>:<port>/v1/bridge
        var comps = URLComponents()
        comps.scheme = "ws"
        comps.host = device.host
        comps.port = device.port
        comps.path = "/v1/bridge"
        return comps.url!
    }

    private func consumeMessages(from t: Transport) async {
        for await msg in t.messageStream {
            await handle(msg)
        }
    }

    private func observeState(of t: Transport) async {
        for await state in t.stateStream {
            await MainActor.run {
                switch state {
                case .idle, .connecting:
                    break
                case .connected:
                    self.status = .connected(via: t.name)
                case .disconnected(let reason):
                    self.status = .disconnected
                    self.lastError = reason
                }
            }
        }
    }

    private func handle(_ msg: Message) async {
        guard BridgeProtocol.supportedVersions.contains(msg.protocolVersion) else {
            Loggers.bridge.error("Dropping message with unsupported version \(msg.protocolVersion, privacy: .public)")
            return
        }
        switch msg.payload {
        case .commandResponse(let resp):
            if let cont = pendingCommands.removeValue(forKey: resp.inReplyTo) {
                cont.resume(returning: resp)
            }
        case .event(let ev):
            eventContinuation.yield(ev)
        case .capabilityRequest(let req):
            capContinuation.yield(req)
        case .error(let err):
            Loggers.bridge.error("Server error: \(err.code, privacy: .public) - \(err.message, privacy: .public)")
            if let inReplyTo = err.inReplyTo, let cont = pendingCommands.removeValue(forKey: inReplyTo) {
                cont.resume(throwing: TransportError.underlying("\(err.code): \(err.message)"))
            }
        case .ping:
            // TODO: send pong
            break
        case .pong, .commandRequest, .capabilityResponse:
            break
        }
    }
}
