import Foundation
import HermesCore

/// A Mac that this iPhone has paired with. Persisted to the Keychain; never to UserDefaults.
public struct PairedDevice: Codable, Hashable, Sendable {
    public let id: String                  // stable device id from the Mac
    public let displayName: String         // user-facing name (e.g. "Justin's MacBook Pro")
    public let host: String                // hostname or IP at pairing time (may be stale)
    public let port: Int                   // WebSocket port on the Mac
    public let fingerprint: String         // pinned cert fingerprint or HMAC of server key
    public let deviceToken: String         // per-device bearer token issued by the Mac
    public let relayRoutingToken: String?  // optional — only present if Mac opted into relay
    public let pairedAt: Date

    public init(id: String, displayName: String, host: String, port: Int,
                fingerprint: String, deviceToken: String, relayRoutingToken: String?, pairedAt: Date = .init()) {
        self.id = id
        self.displayName = displayName
        self.host = host
        self.port = port
        self.fingerprint = fingerprint
        self.deviceToken = deviceToken
        self.relayRoutingToken = relayRoutingToken
        self.pairedAt = pairedAt
    }
}

public enum PairedDeviceStore {
    private static let keychainKey = "hermes.pairedDevices.v1"

    public static func load() -> [PairedDevice] {
        do {
            let data = try Keychain.data(for: keychainKey)
            return try JSONDecoder().decode([PairedDevice].self, from: data)
        } catch Keychain.Error.itemNotFound {
            return []
        } catch {
            Loggers.pairing.error("Failed to load paired devices: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    public static func save(_ devices: [PairedDevice]) throws {
        let data = try JSONEncoder().encode(devices)
        try Keychain.set(data, for: keychainKey)
    }

    public static func add(_ device: PairedDevice) throws {
        var current = load()
        current.removeAll { $0.id == device.id }
        current.append(device)
        try save(current)
    }

    public static func remove(id: String) throws {
        var current = load()
        current.removeAll { $0.id == id }
        try save(current)
    }
}
