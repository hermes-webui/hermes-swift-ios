import Foundation
import Combine

/// User-facing settings persisted in UserDefaults. Endpoints live in the Keychain via
/// `EndpointStore` and `HermesEndpoint` — not here.
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private let defaults: UserDefaults
    private enum Key {
        static let hasCompletedOnboarding = "hermes.hasCompletedOnboarding"
        static let inAppNotificationsEnabled = "hermes.inAppNotificationsEnabled"
    }

    @Published public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }
    @Published public var inAppNotificationsEnabled: Bool {
        didSet { defaults.set(inAppNotificationsEnabled, forKey: Key.inAppNotificationsEnabled) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        self.inAppNotificationsEnabled = defaults.object(forKey: Key.inAppNotificationsEnabled) as? Bool ?? false
    }
}
