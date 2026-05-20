import SwiftUI
import HermesCore
import HermesCapabilities

/// QR scan + manual-URL fallback. Saves a `HermesEndpoint` to the Keychain and activates it.
public struct EndpointSetupView: View {
    @ObservedObject var store: EndpointStore
    @Environment(\.dismiss) private var dismiss

    @State private var manualURL: String = ""
    @State private var manualName: String = ""
    @State private var error: String?
    @State private var working = false
    @State private var showingScanner = false

    public init(store: EndpointStore = .shared) { self.store = store }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Scan QR from Hermes") {
                    Text("Open Hermes on your Mac and choose Share with iPhone. Point your camera at the code.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Open camera", systemImage: "qrcode.viewfinder")
                    }
                }

                Section("Enter URL manually") {
                    TextField("Display name (e.g. Home)", text: $manualName)
                        .textInputAutocapitalization(.words)
                    TextField("https://hermes.tailnet.ts.net", text: $manualURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                    Button(working ? "Connecting…" : "Save & connect") {
                        Task { await saveManual() }
                    }
                    .disabled(manualURL.isEmpty || manualName.isEmpty || working)
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Connect to Hermes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingScanner) {
                QRScannerView(
                    onResult: { value in
                        showingScanner = false
                        Task { await acceptScanned(value) }
                    },
                    onCancel: { showingScanner = false }
                )
            }
        }
    }

    private func acceptScanned(_ raw: String) async {
        working = true
        error = nil
        defer { working = false }
        do {
            let payload = try EndpointQR.decode(raw)
            let endpoint = try EndpointQR.endpoint(from: payload)
            try store.add(endpoint, activate: true)
            dismiss()
        } catch EndpointQR.Error.invalidEncoding {
            error = "That doesn't look like a Hermes connect code. It should start with “hermes:agent:v1:”."
        } catch EndpointQR.Error.unsupportedVersion(let v) {
            error = "This Mac is using share protocol v\(v); update Hermes on either the Mac or the iPhone."
        } catch {
            self.error = "\(error.localizedDescription)"
        }
    }

    private func saveManual() async {
        working = true
        error = nil
        defer { working = false }
        guard let url = URL(string: manualURL), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            error = "URL must be http:// or https://"
            return
        }
        let endpoint = HermesEndpoint(url: url, displayName: manualName)
        do {
            try store.add(endpoint, activate: true)
            dismiss()
        } catch {
            self.error = "\(error.localizedDescription)"
        }
    }
}
