import Foundation

/// Every iPhone-native API exposed to Hermes (camera, location, contacts, ...) conforms to this.
/// Implementations live one folder deep under `Sources/HermesCapabilities/<Name>/`.
public protocol Capability: AnyObject, Sendable {
    /// Identifier used by the JS bridge and the Mac BridgeServer (e.g. "camera", "location").
    var name: String { get }

    /// Current authorization status without prompting.
    func permissionStatus() async -> PermissionStatus

    /// Prompt for permission if needed. Idempotent.
    func requestPermission() async -> PermissionStatus

    /// Invoke a method on this capability. Methods + params are capability-specific —
    /// document them in BRIDGE_PROTOCOL.md when you add new ones.
    func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult
}

public enum PermissionStatus: String, Sendable, Codable {
    case notDetermined
    case denied
    case restricted
    case granted
}

public typealias CapabilityParams = [String: AnyCodable]
public typealias CapabilityResult = AnyCodable

public enum CapabilityError: Error, Equatable {
    case unknownMethod(String)
    case missingParam(String)
    case permissionDenied
    case unsupportedOnDevice
    case underlying(String)
}
