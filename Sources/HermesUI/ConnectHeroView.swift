import SwiftUI
import HermesCore

/// Full-screen first-launch state. Shown when no Hermes endpoint is configured.
/// One tap → camera → scan QR → done.
public struct ConnectHeroView: View {
    @ObservedObject var store: EndpointStore
    @State private var showingSetup = false

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
                    Text("Connect to Hermes")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Scan the QR shown by Hermes on your Mac, or enter your agent URL.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Text("Tip: install Tailscale on both devices to reach your Mac from anywhere — cellular, hotel WiFi, anywhere.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }
                Spacer()
                Button {
                    showingSetup = true
                } label: {
                    Label("Scan to connect", systemImage: "camera.viewfinder")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.white)
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingSetup) {
            EndpointSetupView(store: store)
        }
    }
}
