import SwiftUI

public struct EndpointEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: EndpointStore
    let endpoint: HermesEndpoint

    @State private var host: String
    @State private var secret: String
    @State private var error: String?

    public init(store: EndpointStore = .shared, endpoint: HermesEndpoint) {
        self.store = store
        self.endpoint = endpoint
        _host = State(initialValue: endpoint.url.absoluteString)
        _secret = State(initialValue: endpoint.bearerToken ?? "")
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Host or URL", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.system(.body, design: .monospaced))

                    SecureField("Secret / token", text: $secret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                }

                Section {
                    Button("Save Changes") {
                        save()
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Connection")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        error = nil
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Enter a host or URL."
            return
        }

        let normalized = trimmed.contains("://") ? trimmed : "http://\(trimmed.contains(":") ? trimmed : "\(trimmed):8787")"
        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            error = "Host must be a valid IP or hostname."
            return
        }

        let token = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = HermesEndpoint(
            url: url,
            displayName: url.host ?? trimmed,
            leafCertFingerprint: endpoint.leafCertFingerprint,
            bearerToken: token.isEmpty ? nil : token,
            addedAt: endpoint.addedAt
        )

        do {
            let wasActive = store.activeEndpoint?.url == endpoint.url
            try store.remove(endpoint)
            try store.add(updated, activate: wasActive)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
