import Foundation
import WebKit
import HermesCore
import HermesCapabilities
import HermesBridge

/// Routes JS-side calls (window.hermes.invoke) to native handlers.
/// Single WKScriptMessageHandler — every message arrives via `userContentController(_:didReceive:)`
/// with `message.name == "hermes"`. Don't register additional handler names.
public final class JSBridge: NSObject, WKScriptMessageHandler, @unchecked Sendable {

    private weak var webView: WKWebView?
    private let registry: CapabilityRegistry
    private let session: () -> BridgeClient?

    /// - Parameters:
    ///   - registry: where capability lookups go.
    ///   - session: closure returning the currently-active BridgeClient (or nil). Lazy so the
    ///     bridge can be wired up before the user has paired a Mac.
    public init(registry: CapabilityRegistry = .shared, session: @escaping () -> BridgeClient?) {
        self.registry = registry
        self.session = session
    }

    public func attach(to webView: WKWebView) { self.webView = webView }

    public func userContentController(_ userContentController: WKUserContentController,
                                       didReceive message: WKScriptMessage) {
        guard message.name == "hermes",
              let body = message.body as? [String: Any],
              let id = body["id"] as? String,
              let method = body["method"] as? String else {
            Loggers.webView.error("Malformed JS bridge message")
            return
        }
        let params = body["params"] as? [String: Any] ?? [:]

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.route(method: method, params: params)
                self.deliver(id: id, result: result, error: nil)
            } catch {
                let bridgeError = BridgeError(code: "capability_error", message: "\(error)")
                self.deliver(id: id, result: nil, error: bridgeError)
            }
        }
    }

    /// Method format: `capability.<name>.<method>` or `bridge.<command>`.
    private func route(method: String, params: [String: Any]) async throws -> AnyCodable? {
        let parts = method.split(separator: ".", maxSplits: 2, omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 2 else { throw CapabilityError.unknownMethod(method) }

        switch parts[0] {
        case "capability":
            guard parts.count == 3 else { throw CapabilityError.unknownMethod(method) }
            let capabilityName = parts[1]
            let methodName = parts[2]
            guard let cap = await registry.capability(named: capabilityName) else {
                throw CapabilityError.unknownMethod("unknown capability \(capabilityName)")
            }
            let typed = try Self.codableParams(params)
            return try await cap.invoke(method: methodName, params: typed)

        case "bridge":
            // Forward to the Mac via the active BridgeClient.
            guard parts.count >= 2 else { throw CapabilityError.unknownMethod(method) }
            guard let client = session() else { throw CapabilityError.underlying("no active bridge session") }
            let commandName = parts.dropFirst().joined(separator: ".")
            let jsonParams = try Self.jsonValue(from: params)
            let result = try await client.run(command: commandName, params: jsonParams)
            return try result.map { try AnyCodable(forwarding: $0) }

        default:
            throw CapabilityError.unknownMethod(method)
        }
    }

    private func deliver(id: String, result: AnyCodable?, error: BridgeError?) {
        let payload: [String: Any] = [
            "id": id,
            "result": (try? result.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) }) as Any? ?? NSNull(),
            "error": error.map { ["code": $0.code, "message": $0.message] } as Any? ?? NSNull(),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        let js = "window.hermes.deliverResponse(\(json));"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    // MARK: - Conversion helpers

    private static func codableParams(_ raw: [String: Any]) throws -> CapabilityParams {
        var out: CapabilityParams = [:]
        for (k, v) in raw {
            out[k] = try toAnyCodable(v)
        }
        return out
    }

    private static func toAnyCodable(_ v: Any) throws -> AnyCodable {
        if v is NSNull { return .null }
        if let b = v as? Bool { return .bool(b) }
        if let i = v as? Int { return .int(i) }
        if let d = v as? Double { return .double(d) }
        if let s = v as? String { return .string(s) }
        if let a = v as? [Any] { return .array(try a.map(toAnyCodable)) }
        if let o = v as? [String: Any] {
            var dict: [String: AnyCodable] = [:]
            for (k, val) in o { dict[k] = try toAnyCodable(val) }
            return .object(dict)
        }
        return .null
    }

    private static func jsonValue(from raw: [String: Any]) throws -> JSONValue {
        let data = try JSONSerialization.data(withJSONObject: raw)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}

private extension AnyCodable {
    /// Forward a HermesBridge JSONValue into AnyCodable without coupling the modules in the type system.
    init(forwarding value: JSONValue) throws {
        let data = try JSONEncoder().encode(value)
        self = try JSONDecoder().decode(AnyCodable.self, from: data)
    }
}
