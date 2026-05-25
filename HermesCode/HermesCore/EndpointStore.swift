import Foundation
import Combine

/// Keychain-backed store of `HermesEndpoint`s. Also tracks the user's active selection.
/// Tokens live alongside their endpoint inside the same blob — all secrets, all Keychain.
@MainActor
public final class EndpointStore: ObservableObject {
    public static let shared = EndpointStore()

    @Published public private(set) var endpoints: [HermesEndpoint] = []
    @Published public private(set) var activeEndpoint: HermesEndpoint?

    private static let endpointsKey = "hermes.endpoints.v1"
    private static let activeURLKey  = "hermes.activeEndpoint.v1"

    public init() {
        reload()
    }

    public func reload() {
        endpoints = Self.loadEndpoints()
        if let urlString = try? Keychain.string(for: Self.activeURLKey),
           let url = URL(string: urlString),
           let match = endpoints.first(where: { $0.url == url }) {
            activeEndpoint = match
        } else {
            activeEndpoint = endpoints.first
        }
    }

    public func add(_ endpoint: HermesEndpoint, activate: Bool = true) throws {
        var current = endpoints
        current.removeAll { $0.url == endpoint.url }
        current.append(endpoint)
        try Self.saveEndpoints(current)
        endpoints = current
        if activate { try setActive(endpoint) }
    }

    public func remove(_ endpoint: HermesEndpoint) throws {
        var current = endpoints
        current.removeAll { $0.url == endpoint.url }
        try Self.saveEndpoints(current)
        endpoints = current
        if activeEndpoint?.url == endpoint.url {
            try? Keychain.delete(Self.activeURLKey)
            activeEndpoint = endpoints.first
        }
    }

    public func setActive(_ endpoint: HermesEndpoint) throws {
        try Keychain.setString(endpoint.url.absoluteString, for: Self.activeURLKey)
        activeEndpoint = endpoint
    }

    // MARK: - Persistence

    private static func loadEndpoints() -> [HermesEndpoint] {
        do {
            let data = try Keychain.data(for: endpointsKey)
            return try JSONDecoder().decode([HermesEndpoint].self, from: data)
        } catch Keychain.Error.itemNotFound {
            return []
        } catch {
            Loggers.app.error("Failed to load endpoints: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func saveEndpoints(_ endpoints: [HermesEndpoint]) throws {
        let data = try JSONEncoder().encode(endpoints)
        try Keychain.set(data, for: endpointsKey)
    }
}
