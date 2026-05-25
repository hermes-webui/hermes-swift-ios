import SwiftUI

/// Full-screen first-launch state. Shown when no Hermes endpoint is configured.
public struct ConnectHeroView: View {
    @ObservedObject var store: EndpointStore
    @State private var manualHost: String = ""
    @State private var manualSecret: String = ""
    @State private var error: String?
    @State private var working = false
    @State private var showingScanner = false

    public init(store: EndpointStore = .shared) { self.store = store }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hue: 0.62, saturation: 0.18, brightness: 0.18),
                         Color(hue: 0.70, saturation: 0.24, brightness: 0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    Circle().fill(.white.opacity(0.08)).frame(width: 180, height: 180)
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 88, weight: .light))
                        .foregroundStyle(.white)
                }
                VStack(spacing: 12) {
                    Text("Connect")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Enter IP and secret, or scan the QR code.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Text("Use Tailscale on both devices for the connection.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }
                VStack(spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(spacing: 12) {
                            TextField("IP or hostname", text: $manualHost)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                            SecureField("Secret / token", text: $manualSecret)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                        }

                        Button {
                            showingScanner = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title2)
                                Text("QR")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(width: 58, height: 96)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.black)
                    }
                    .frame(maxWidth: 420)

                    Button(working ? "Connecting…" : "Connect") {
                        Task { await saveManual() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .disabled(manualHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)

                    Text("Port `8787` is used unless you include one.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))

                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.95))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                Spacer()
                .padding(.bottom, 32)
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

    private func acceptScanned(_ raw: String) async {
        working = true
        error = nil
        defer { working = false }
        do {
            let payload = try EndpointQR.decode(raw)
            let endpoint = try EndpointQR.endpoint(from: payload)
            try store.add(endpoint, activate: true)
        } catch EndpointQR.Error.invalidEncoding {
            error = "That doesn't look like a Hermes connect code. It should start with \"hermes:agent:v1:\"."
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
        let host = manualHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            error = "Enter a Tailscale IP or hostname."
            return
        }
        let normalized = host.contains("://") ? host : "http://\(host.contains(":") ? host : "\(host):8787")"
        guard let url = URL(string: normalized), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            error = "Host must be a valid IP or hostname."
            return
        }
        let secret = manualSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = HermesEndpoint(
            url: url,
            displayName: host,
            bearerToken: secret.isEmpty ? nil : secret
        )
        do {
            try store.add(endpoint, activate: true)
        } catch {
            self.error = "\(error.localizedDescription)"
        }
    }
}
