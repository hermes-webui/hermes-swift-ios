import Foundation
import HermesCore

/// WebSocket transport for LAN connections to a paired Mac BridgeServer.
/// Authentication: bearer token (from pairing) sent as the `Authorization` header on the initial handshake.
public final class WebSocketTransport: NSObject, Transport, @unchecked Sendable {
    public let name = "websocket"

    private let url: URL
    private let token: String
    private let pinner: FingerprintPinner?
    private var session: URLSession!
    private var task: URLSessionWebSocketTask?

    private let stateLock = NSLock()
    private var _state: TransportState = .idle
    private var stateContinuation: AsyncStream<TransportState>.Continuation?
    private var messageContinuation: AsyncStream<Message>.Continuation?

    public let stateStream: AsyncStream<TransportState>
    public let messageStream: AsyncStream<Message>

    public var state: TransportState {
        stateLock.lock(); defer { stateLock.unlock() }
        return _state
    }

    /// - Parameters:
    ///   - url: full WebSocket URL (use `wss://` in production; `ws://` is accepted for local dev).
    ///   - token: bearer token issued during pairing.
    ///   - pinner: when `url` is `wss://`, pass a `FingerprintPinner` configured with the paired Mac's
    ///     leaf-cert fingerprint. Mismatches will terminate the TLS handshake. Pass nil only for
    ///     `ws://` (no TLS to pin) or when audit-only inspection is sufficient.
    public init(url: URL, token: String, pinner: FingerprintPinner? = nil) {
        self.url = url
        self.token = token
        self.pinner = pinner

        var stateCont: AsyncStream<TransportState>.Continuation!
        self.stateStream = AsyncStream { stateCont = $0 }
        var msgCont: AsyncStream<Message>.Continuation!
        self.messageStream = AsyncStream { msgCont = $0 }

        super.init()
        self.stateContinuation = stateCont
        self.messageContinuation = msgCont
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

        if pinner == nil, url.scheme?.lowercased() == "wss" {
            Loggers.transport.error("wss:// without a FingerprintPinner — cert pinning is OFF. This is unsafe in production.")
        }
    }

    public func connect() async throws {
        setState(.connecting)
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("\(BridgeProtocol.currentVersion)", forHTTPHeaderField: "X-Hermes-Protocol-Version")

        let task = session.webSocketTask(with: req)
        self.task = task
        task.resume()
        receiveLoop()
        setState(.connected)
    }

    public func send(_ message: Message) async throws {
        guard let task else { throw TransportError.notConnected }
        let data = try JSONEncoder.bridge.encode(message)
        try await task.send(.data(data))
    }

    public func disconnect() async {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        setState(.disconnected(reason: "client requested"))
    }

    private func receiveLoop() {
        guard let task else { return }
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let err):
                Loggers.transport.error("WebSocket receive failed: \(err.localizedDescription, privacy: .public)")
                self.setState(.disconnected(reason: err.localizedDescription))
            case .success(let msg):
                self.handle(msg)
                self.receiveLoop()
            }
        }
    }

    private func handle(_ msg: URLSessionWebSocketTask.Message) {
        let data: Data
        switch msg {
        case .data(let d):    data = d
        case .string(let s):  data = s.data(using: .utf8) ?? Data()
        @unknown default:     return
        }
        do {
            let decoded = try JSONDecoder.bridge.decode(Message.self, from: data)
            guard BridgeProtocol.supportedVersions.contains(decoded.protocolVersion) else {
                Loggers.transport.error("Unsupported bridge protocol version \(decoded.protocolVersion, privacy: .public)")
                return
            }
            messageContinuation?.yield(decoded)
        } catch {
            Loggers.transport.error("Failed to decode bridge message: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func setState(_ newState: TransportState) {
        stateLock.lock(); _state = newState; stateLock.unlock()
        stateContinuation?.yield(newState)
    }
}

extension WebSocketTransport: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Loggers.transport.info("WebSocket opened")
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "code \(closeCode.rawValue)"
        Loggers.transport.info("WebSocket closed: \(reasonString, privacy: .public)")
        setState(.disconnected(reason: reasonString))
    }

    /// Forward server-trust challenges to the fingerprint pinner when present.
    /// Without a pinner, default handling applies (system trust store).
    public func urlSession(_ session: URLSession,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let pinner = self.pinner {
            pinner.urlSession(session, didReceive: challenge, completionHandler: completionHandler)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

extension JSONEncoder {
    static let bridge: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
}
extension JSONDecoder {
    static let bridge = JSONDecoder()
}
