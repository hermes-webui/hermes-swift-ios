import Foundation
import os

/// Central lookup table for capabilities. The JS bridge routes all capability calls through this.
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
    /// Microphone, Photo Library) very closely. Importing those frameworks but never invoking
    /// them can also trigger Apple's automated privacy-manifest warnings — we deleted the
    /// LocationCapability and ContactsCapability files entirely rather than keeping dead code.
    /// Resurrect from git history if/when a real flow needs them.
    public func registerDefaults() {
        // Permission-gated (declared in project.yml)
        register(CameraCapability())            // NSCameraUsageDescription
        register(BiometricsCapability())        // NSFaceIDUsageDescription
        register(NotificationsCapability())     // requested at runtime
        // No-permission utility capabilities.
        register(ShareSheetCapability())
        register(ClipboardCapability())
        register(HapticsCapability())
        register(DeviceInfoCapability())
        register(OpenURLCapability())
        register(AppBadgeCapability())
        register(SpeechSynthesisCapability())
        register(SpeechRecognitionCapability())
        register(QRGeneratorCapability())
        register(DocumentPickerCapability())
    }
}
