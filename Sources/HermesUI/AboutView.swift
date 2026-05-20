import SwiftUI

/// Short "what is this" screen surfaced from Settings. Two jobs:
///   1. Tell users what the app does (it's not just a webview).
///   2. Give App Review a one-screen explanation of the product.
public struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Hermes")
                        .font(.largeTitle.weight(.semibold))
                    Text("Native iOS client for Hermes Agent.")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Group {
                        sectionHeader("What it does")
                        Text("Loads your configured Hermes Agent dashboard in a WebKit view and gives the dashboard access to iPhone-native APIs — camera, biometrics, notifications, share sheet, clipboard, haptics, document picker, text-to-speech, QR generation, and more — via a JavaScript bridge.")

                        sectionHeader("How you connect")
                        Text("Scan the QR shown by Hermes on your Mac, or paste your agent URL. The URL plus optional TLS fingerprint and bearer token are stored in the iOS Keychain. The app does not transmit your data anywhere except to the agent endpoint you configured.")

                        sectionHeader("Reachability")
                        Text("The iPhone reaches your agent over whatever network path you set up — Tailscale, public domain, LAN, ngrok, anything that resolves the URL you entered. Hermes does not operate any relay or coordination server of its own.")

                        sectionHeader("Privacy")
                        Text("Endpoint URLs, tokens, and fingerprints live in the iOS Keychain. No telemetry, no analytics, no third-party SDKs.")
                    }

                    Group {
                        sectionHeader("Source")
                        Link("github.com/hermes-webui/hermes-swift-ios",
                             destination: URL(string: "https://github.com/hermes-webui/hermes-swift-ios")!)
                        Link("github.com/hermes-webui/hermes-swift-mac",
                             destination: URL(string: "https://github.com/hermes-webui/hermes-swift-mac")!)
                    }
                    .font(.callout)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 8)
    }
}
