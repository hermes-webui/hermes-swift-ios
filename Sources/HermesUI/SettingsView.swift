import SwiftUI
import HermesBridge
import HermesCore

public struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var session: SessionManager
    @State private var showingPairing = false
    @State private var urlInput: String = ""

    public init(settings: AppSettings = .shared, session: SessionManager = .shared) {
        self.settings = settings
        self.session = session
        self._urlInput = State(initialValue: settings.webViewURL.absoluteString)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Hermes Web UI") {
                    TextField("URL", text: $urlInput)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { applyURL() }
                    Button("Apply") { applyURL() }
                }

                Section("Paired Macs") {
                    if session.pairedDevices.isEmpty {
                        Text("No Macs paired").foregroundStyle(.secondary)
                    } else {
                        ForEach(session.pairedDevices, id: \.id) { device in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.displayName)
                                    Text("\(device.host):\(device.port)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Connect") {
                                    Task { await session.connect(to: device) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .onDelete { idxs in
                            for i in idxs {
                                try? session.remove(id: session.pairedDevices[i].id)
                            }
                        }
                    }
                    Button("Pair a new Mac") { showingPairing = true }
                }

                Section("Transport") {
                    Picker("Preference", selection: $settings.preferredTransport) {
                        ForEach(TransportPreference.allCases) { Text($0.displayName).tag($0) }
                    }
                    TextField("Relay base URL", text: Binding(
                        get: { settings.relayBaseURL.absoluteString },
                        set: { if let u = URL(string: $0) { settings.relayBaseURL = u } }
                    ))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }

                Section("Connection") {
                    ConnectionStatusView(session: session)
                    if session.activeClient != nil {
                        Button("Disconnect") { Task { await session.disconnect() } }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPairing) { PairingView(session: session) }
        }
    }

    private func applyURL() {
        guard let url = URL(string: urlInput) else { return }
        settings.webViewURL = url
    }
}
