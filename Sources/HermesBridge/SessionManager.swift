import Foundation
import Combine
import UIKit
import HermesCore

/// Owns the active BridgeClient. Re-connects when the app foregrounds, drops on background per iOS rules.
@MainActor
public final class SessionManager: ObservableObject {
    public static let shared = SessionManager()

    @Published public private(set) var pairedDevices: [PairedDevice] = []
    @Published public private(set) var activeClient: BridgeClient?

    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?

    public init() {
        self.pairedDevices = PairedDeviceStore.load()
        observeAppLifecycle()
    }

    deinit {
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
    }

    public func connect(to device: PairedDevice, settings: AppSettings = .shared) async {
        await activeClient?.disconnect()
        let client = BridgeClient(device: device,
                                  preference: settings.preferredTransport,
                                  relayBaseURL: settings.relayBaseURL)
        self.activeClient = client
        await client.connect()
    }

    public func disconnect() async {
        await activeClient?.disconnect()
        self.activeClient = nil
    }

    public func addPaired(_ device: PairedDevice) throws {
        try PairedDeviceStore.add(device)
        pairedDevices = PairedDeviceStore.load()
    }

    public func remove(id: String) throws {
        try PairedDeviceStore.remove(id: id)
        pairedDevices = PairedDeviceStore.load()
        if activeClient?.device.id == id {
            Task { await disconnect() }
        }
    }

    private func observeAppLifecycle() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if let device = self.activeClient?.device {
                    await self.connect(to: device)
                }
            }
        }
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.activeClient?.disconnect() }
        }
    }
}
