import Foundation
import Combine

/// User-facing settings persisted in UserDefaults. Endpoints + tokens live in the Keychain via
/// `EndpointStore` and `HermesEndpoint` — not here.
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    public enum VoiceInputMode: String, CaseIterable {
        case pushToTalk
        case realtime
    }

    private let defaults: UserDefaults
    private enum Key {
        static let hasCompletedOnboarding = "hermes.hasCompletedOnboarding"
        static let voiceInputMode = "hermes.voiceInputMode"
        static let inAppNotificationsEnabled = "hermes.inAppNotificationsEnabled"
    }

    @Published public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }
    @Published public var voiceInputMode: VoiceInputMode {
        didSet { defaults.set(voiceInputMode.rawValue, forKey: Key.voiceInputMode) }
    }
    @Published public var inAppNotificationsEnabled: Bool {
        didSet { defaults.set(inAppNotificationsEnabled, forKey: Key.inAppNotificationsEnabled) }
    }
    @Published public var reconnectNonce: Int = 0

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        let storedMode = defaults.string(forKey: Key.voiceInputMode) ?? ""
        if storedMode == "autoListen" {
            self.voiceInputMode = .realtime
        } else {
            self.voiceInputMode = VoiceInputMode(rawValue: storedMode) ?? .pushToTalk
        }
        self.inAppNotificationsEnabled = defaults.object(forKey: Key.inAppNotificationsEnabled) as? Bool ?? false
    }

    public func triggerReconnect() {
        reconnectNonce &+= 1
    }
}
