import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var store: EndpointStore
    @State private var editingEndpoint: HermesEndpoint?
    @State private var manualHost: String = ""
    @State private var manualSecret: String = ""
    @State private var manualError: String?
    @State private var manualWorking = false
    @State private var showingScanner = false
    @Environment(\.openURL) private var openURL

    public init(store: EndpointStore = .shared) { self.store = store }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Connections") {
                    HStack {
                        Spacer()
                        Button {
                            if let url = URL(string: "https://apps.apple.com/us/app/tailscale/id1470499037") {
                                openURL(url)
                            }
                        } label: {
                            Text("Get Tailscale (App Store)")
                        }
                        .font(.footnote)
                        Spacer()
                    }

                    Text("1) Sign in to Tailscale on both devices.\n2) Confirm both are Connected.\n3) Connect with QR or manual fields.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button {
                            showingScanner = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title3)
                                Text("Scan QR")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(width: 88, height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 12) {
                        Rectangle().fill(.secondary.opacity(0.25)).frame(height: 1)
                        Text("or")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Rectangle().fill(.secondary.opacity(0.25)).frame(height: 1)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Manual")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 0) {
                            TextField("Tailnet host or username", text: $manualHost)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                                .padding(.vertical, 10)

                            Divider()

                            SecureField("WebUI password", text: $manualSecret)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                                .padding(.vertical, 10)
                        }
                        .padding(.horizontal, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.secondary.opacity(0.22), lineWidth: 1)
                        )

                        Button(manualWorking ? "Connecting…" : "Connect") {
                            Task { await saveManualConnection() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(manualHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manualWorking)

                        Text("Password hint: set `HERMES_WEBUI_PASSWORD` on the WebUI machine.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)

                    Text("Default port is `8787`.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let manualError {
                        Text(manualError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if !store.endpoints.isEmpty {
                        Divider()
                        Text("Saved connections")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(store.endpoints) { endpoint in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(endpoint.displayName)
                                    Text(endpoint.url.absoluteString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                if store.activeEndpoint?.url == endpoint.url {
                                    Text("Active").font(.caption).foregroundStyle(.green)
                                } else {
                                    Button("Use") {
                                        try? store.setActive(endpoint)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    try? store.remove(endpoint)
                                }
                                Button("Edit") {
                                    editingEndpoint = endpoint
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Reconnect") {
                                    try? store.setActive(endpoint)
                                    settings.triggerReconnect()
                                }
                                .tint(.green)
                            }
                        }
                        .onDelete { idxs in
                            for i in idxs {
                                try? store.remove(store.endpoints[i])
                            }
                        }
                    }
                }

            }
            .navigationTitle("Connections")
            .toolbar { EditButton() }
            .sheet(item: $editingEndpoint) { endpoint in
                EndpointEditorView(store: store, endpoint: endpoint)
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
        manualWorking = true
        manualError = nil
        defer { manualWorking = false }
        do {
            let payload = try EndpointQR.decode(raw)
            let endpoint = try EndpointQR.endpoint(from: payload)
            try store.add(endpoint, activate: true)
        } catch EndpointQR.Error.invalidEncoding {
            manualError = "That doesn't look like a Hermes connect code. It should start with \"hermes:agent:v1:\"."
        } catch EndpointQR.Error.unsupportedVersion(let v) {
            manualError = "This Mac is using share protocol v\(v); update Hermes on either the Mac or the iPhone."
        } catch {
            manualError = error.localizedDescription
        }
    }

    private func saveManualConnection() async {
        manualWorking = true
        manualError = nil
        defer { manualWorking = false }

        let host = manualHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            manualError = "Enter a Tailscale host."
            return
        }

        let normalized = host.contains("://") ? host : "http://\(host.contains(":") ? host : "\(host):8787")"
        guard let url = URL(string: normalized), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            manualError = "Host must be a valid IP or hostname."
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
            manualError = error.localizedDescription
        }
    }
}
