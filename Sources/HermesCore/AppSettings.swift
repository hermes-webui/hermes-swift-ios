import Foundation
import Combine

/// User-facing settings persisted in UserDefaults. Tokens and other secrets go in `Keychain`, not here.
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private let defaults: UserDefaults
    private enum Key {
        static let webViewURL = "hermes.webViewURL"
        static let preferredTransport = "hermes.preferredTransport"
        static let relayBaseURL = "hermes.relayBaseURL"
        static let hasCompletedOnboarding = "hermes.hasCompletedOnboarding"
    }

    @Published public var webViewURL: URL {
        didSet { defaults.set(webViewURL.absoluteString, forKey: Key.webViewURL) }
    }

    @Published public var preferredTransport: TransportPreference {
        didSet { defaults.set(preferredTransport.rawValue, forKey: Key.preferredTransport) }
    }

    @Published public var relayBaseURL: URL {
        didSet { defaults.set(relayBaseURL.absoluteString, forKey: Key.relayBaseURL) }
    }

    @Published public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.webViewURL = URL(string: defaults.string(forKey: Key.webViewURL) ?? "https://hermes.local/")!
        self.preferredTransport = TransportPreference(rawValue: defaults.string(forKey: Key.preferredTransport) ?? "") ?? .auto
        self.relayBaseURL = URL(string: defaults.string(forKey: Key.relayBaseURL) ?? "https://relay.hermes-webui.dev/")!
        self.hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
    }
}

public enum TransportPreference: String, CaseIterable, Identifiable {
    case auto       // prefer LAN, fall back to relay
    case lanOnly
    case relayOnly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .auto:      return "Auto (LAN, then relay)"
        case .lanOnly:   return "LAN only"
        case .relayOnly: return "Relay only"
        }
    }
}
