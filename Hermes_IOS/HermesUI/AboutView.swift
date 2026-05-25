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
                    Text("webui Connector")
                        .font(.largeTitle.weight(.semibold))
                    Text("Native iOS client for any webui.")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Group {
                        sectionHeader("What it does")
                        Text("Loads your configured webui in a WebKit view and gives it access to phone-native APIs — camera, biometrics, notifications, share sheet, clipboard, haptics, document picker, text-to-speech, QR generation, and more — via a JavaScript bridge.")

                        sectionHeader("How you connect")
                        Text("Scan a connect QR code, or enter your Tailscale machine address manually. The endpoint is stored in the iOS Keychain. The app only connects to endpoints you configure.")

                        sectionHeader("Tailscale")
                        Text("To reach your webui machine from anywhere (cellular, hotel Wi-Fi, etc.), install Tailscale on both devices, then use the machine's Tailscale hostname or IP.")
                        Link("Get Tailscale", destination: URL(string: "https://apps.apple.com/us/app/tailscale/id1470499037")!)
                            .padding(.top, 4)

                        sectionHeader("Privacy")
                        Text("Endpoint connection data lives in the iOS Keychain. No telemetry, no analytics, no third-party SDKs.")
                    }

                    Group {
                        sectionHeader("Source")
                        Link("github.com/hermes-webui/hermes-swift-ios",
                             destination: URL(string: "https://github.com/hermes-webui/hermes-swift-ios")!)
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
