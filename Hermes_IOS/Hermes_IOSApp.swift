import SwiftUI
import os

@main
struct HermesiOSApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var store = EndpointStore.shared

    init() {
        Task {
            await CapabilityRegistry.shared.registerDefaults()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .onOpenURL { handleDeepLink($0) }
        }
    }

    /// Accepts `hermes://agent?payload=<base64>` deep links so a user can share an endpoint via
    /// any text/AirDrop channel as an alternative to the QR.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "hermes", url.host == "agent" else { return }
        do {
            let payload = try EndpointQR.decode(url.absoluteString)
            let endpoint = try EndpointQR.endpoint(from: payload)
            Task { @MainActor in
                try? store.add(endpoint, activate: true)
            }
        } catch {
            Loggers.app.error("Endpoint deep link failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
