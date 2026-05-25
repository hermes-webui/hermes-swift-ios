import Foundation
import Combine

/// User-facing settings persisted in UserDefaults. Endpoints + tokens live in the Keychain via
/// `EndpointStore` and `HermesEndpoint` — not here.
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private let defaults: UserDefaults
    private enum Key {
        static let hasCompletedOnboarding = "hermes.hasCompletedOnboarding"
    }

    @Published public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
    }
}
