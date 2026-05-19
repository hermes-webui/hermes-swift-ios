import SwiftUI
import HermesBridge
import HermesCore

/// Scans the QR displayed by hermes-swift-mac's BridgeServer and stores the resulting PairedDevice.
/// QR-scanning UI is intentionally stubbed: a real implementation lives in
/// HermesCapabilities/Camera/CameraCapability.scanQR — wire that in once it's built.
public struct PairingView: View {
    @ObservedObject var session: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var manualPayload: String = ""
    @State private var error: String?
    @State private var working = false

    public init(session: SessionManager = .shared) { self.session = session }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Scan QR from your Mac") {
                    // TODO: replace with live camera preview from CameraCapability.scanQR
                    Text("Open Hermes on your Mac → Preferences → Pair an iPhone. Scan the QR with your camera, or paste the payload below.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Open camera") {
                        // TODO: present camera scanner
                    }
                    .disabled(true)
                }
                Section("Paste payload (fallback)") {
                    TextField("hermes:pair:v1:...", text: $manualPayload, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                    Button(working ? "Pairing…" : "Pair") {
                        Task { await pair() }
                    }
                    .disabled(manualPayload.isEmpty || working)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Pair a Mac")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func pair() async {
        working = true
        defer { working = false }
        do {
            let payload = try QRPairing.decode(manualPayload.trimmingCharacters(in: .whitespacesAndNewlines))
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
            await session.connect(to: device)
            dismiss()
        } catch {
            self.error = "\(error)"
        }
    }
}
