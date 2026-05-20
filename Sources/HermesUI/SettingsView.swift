import SwiftUI
import HermesCore

public struct SettingsView: View {
    @ObservedObject var store: EndpointStore
    @State private var showingSetup = false

    public init(store: EndpointStore = .shared) { self.store = store }

    public var body: some View {
        NavigationStack {
            Form {
                // Connect action — first section, prominent. Always available.
                Section {
                    Button {
                        showingSetup = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "qrcode.viewfinder").font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.endpoints.isEmpty ? "Connect to Hermes" : "Add another Hermes")
                                    .font(.headline)
                                Text("Scan the code shown by Hermes on your Mac")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                if !store.endpoints.isEmpty {
                    Section("Configured agents") {
                        ForEach(store.endpoints) { endpoint in
                            HStack {
                                VStack(alignment: .leading) {
                                    HStack(spacing: 6) {
                                        Text(endpoint.displayName)
                                        if endpoint.leafCertFingerprint != nil {
                                            Image(systemName: "lock.shield.fill")
                                                .foregroundStyle(.green)
                                                .help("TLS cert pinned")
                                        }
                                    }
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
                        }
                        .onDelete { idxs in
                            for i in idxs {
                                try? store.remove(store.endpoints[i])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingSetup) { EndpointSetupView(store: store) }
        }
    }
}
