import Foundation
import HermesCore

/// Central lookup table for capabilities. The JS bridge and the Mac BridgeServer both go through this.
/// Registration is lazy — instantiating a Capability MUST NOT trigger permission prompts.
public actor CapabilityRegistry {
    public static let shared = CapabilityRegistry()

    private var capabilities: [String: Capability] = [:]

    public init() {}

    public func register(_ capability: Capability) {
        capabilities[capability.name] = capability
        Loggers.capabilities.info("Registered capability: \(capability.name, privacy: .public)")
    }

    public func capability(named name: String) -> Capability? {
        capabilities[name]
    }

    public func allNames() -> [String] {
        Array(capabilities.keys).sorted()
    }

    /// Convenience: registers the default set shipped with the app.
    /// Add new capabilities to this list and to `HermesCapabilities/<Name>/` together.
    public func registerDefaults() {
        register(CameraCapability())
        register(LocationCapability())
        register(ContactsCapability())
        register(NotificationsCapability())
        register(ShareSheetCapability())
        register(BiometricsCapability())
    }
}
