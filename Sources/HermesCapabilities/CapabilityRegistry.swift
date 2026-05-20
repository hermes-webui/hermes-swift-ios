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

    /// Capabilities auto-registered on launch.
    ///
    /// IMPORTANT for App Store review: only register capabilities whose permission strings are
    /// declared in project.yml AND whose user-facing flow is implemented. Apple rejects apps
    /// that request permissions they don't use, and scrutinizes high-risk surfaces (Contacts,
    /// Microphone, Photo Library) very closely.
    ///
    /// Capabilities staged for later registration once their flows ship:
    ///   - LocationCapability    (needs NSLocationWhenInUseUsageDescription + a visible flow)
    ///   - ContactsCapability    (highest review risk — keep deferred until clearly justified)
    public func registerDefaults() {
        // Permission-gated (declared in project.yml)
        register(CameraCapability())            // NSCameraUsageDescription
        register(BiometricsCapability())        // NSFaceIDUsageDescription
        register(NotificationsCapability())     // requested at runtime
        // No-permission utility capabilities — safe to ship at v0.1.
        register(ShareSheetCapability())
        register(ClipboardCapability())
        register(HapticsCapability())
        register(DeviceInfoCapability())
        register(OpenURLCapability())
        register(AppBadgeCapability())
        register(SpeechSynthesisCapability())
        register(QRGeneratorCapability())
        register(DocumentPickerCapability())
    }
}
