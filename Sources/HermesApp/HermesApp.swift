import SwiftUI
import HermesCore
import HermesBridge
import HermesCapabilities
import HermesWebView
import HermesUI

@main
struct HermesiOSApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var session = SessionManager.shared

    init() {
        Task {
            await CapabilityRegistry.shared.registerDefaults()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(session)
                .onOpenURL { handleDeepLink($0) }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // hermes://pair?payload=<base64>
        guard url.scheme == "hermes" else { return }
        guard url.host == "pair" else { return }
        do {
            let payload = try QRPairing.decode(url.absoluteString)
            let device = PairedDevice(
                id: payload.deviceId,
                displayName: payload.displayName,
                host: payload.host,
                port: payload.port,
                fingerprint: payload.fingerprint,
                deviceToken: payload.deviceToken,
                relayRoutingToken: payload.relayRoutingToken
            )
            try session.addPaired(device)
            Task { await session.connect(to: device) }
        } catch {
            Loggers.app.error("Pairing deep link failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
