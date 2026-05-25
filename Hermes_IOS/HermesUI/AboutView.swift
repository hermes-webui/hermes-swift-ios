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

                        sectionHeader("Reachability — Tailscale recommended")
                        Text("To reach your Mac from anywhere (cellular, hotel WiFi, etc.), install Tailscale on both your Mac and iPhone and use your Mac's tailnet hostname as the agent URL. Tailscale is free for personal use and gives you a stable address with zero port forwarding.")
                        Text("Other setups work too — LAN-only, public domain with TLS, Cloudflare Tunnel, ngrok — the app accepts any URL. Hermes does not operate any relay or coordination server of its own.")
                            .padding(.top, 4)
                        Link("Get Tailscale", destination: URL(string: "https://apps.apple.com/us/app/tailscale/id1470499037")!)
                            .padding(.top, 4)

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
