import SwiftUI
import HermesBridge
import HermesCapabilities
import HermesCore

/// Pair this iPhone with a Mac running hermes-swift-mac.
///
/// Flow:
///   1. Mac displays a QR encoding a `PairingPayload` (host, port, fingerprint, deviceToken, ...)
///   2. iPhone scans via `QRScannerView` (live AVCaptureSession)
///   3. Scanned string is decoded by `QRPairing.decode`, persisted to the Keychain via `PairedDevice`,
///      and the BridgeClient opens a WebSocket immediately
///
/// Manual-payload fallback exists for accessibility, dev work, and the "AirDrop the link to your phone" path.
public struct PairingView: View {
    @ObservedObject var session: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var manualPayload: String = ""
    @State private var error: String?
    @State private var working = false
    @State private var showingScanner = false

    public init(session: SessionManager = .shared) { self.session = session }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Scan QR from your Mac") {
                    Text("Open Hermes on your Mac → Preferences → Pair an iPhone, then point your camera at the code shown there.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Open camera", systemImage: "qrcode.viewfinder")
                    }
                }
                Section("Paste payload (fallback)") {
                    TextField("hermes:pair:v1:…", text: $manualPayload, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                    Button(working ? "Pairing…" : "Pair") {
                        Task { await pair(with: manualPayload) }
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
            .sheet(isPresented: $showingScanner) {
                QRScannerView(
                    onResult: { value in
                        showingScanner = false
                        Task { await pair(with: value) }
                    },
                    onCancel: { showingScanner = false }
                )
            }
        }
    }

    private func pair(with raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        working = true
        error = nil
        defer { working = false }
        do {
            let payload = try QRPairing.decode(trimmed)
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
        } catch QRPairing.Error.invalidEncoding {
            self.error = "That doesn't look like a Hermes pairing code. Make sure it starts with “hermes:pair:v1:”."
        } catch QRPairing.Error.unsupportedVersion(let v) {
            self.error = "This Mac is using pairing protocol v\(v); update Hermes on the Mac (or the iPhone app)."
        } catch {
            self.error = "\(error.localizedDescription)"
        }
    }
}
