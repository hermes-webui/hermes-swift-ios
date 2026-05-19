import SwiftUI
import HermesBridge

/// Full-screen first-launch state. Shown when no Macs are paired yet.
/// The "Pair your Mac" CTA is the entire screen — pulling out the phone, opening the app, and
/// tapping the button should land you at the camera scanner in two taps.
public struct PairHeroView: View {
    @ObservedObject var session: SessionManager
    @State private var showingPairing = false

    public init(session: SessionManager = .shared) { self.session = session }

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
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 180, height: 180)
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 88, weight: .light))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 12) {
                    Text("Pair with your Mac")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Open Hermes on your Mac and choose Pair iPhone, then point your camera at the code.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button {
                    showingPairing = true
                } label: {
                    Label("Scan pairing code", systemImage: "camera.viewfinder")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.white)
                .foregroundStyle(.black)
                .padding(.horizontal, 24)

                Button("I'll pair later") {
                    // Surface settings so the user can configure the web view URL without pairing.
                    showingPairing = false
                    NotificationCenter.default.post(name: .hermesOpenSettings, object: nil)
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingPairing) {
            PairingView(session: session)
        }
    }
}

public extension Notification.Name {
    /// Posted by PairHeroView's "I'll pair later" button. RootView observes this and opens Settings.
    static let hermesOpenSettings = Notification.Name("com.hermeswebui.openSettings")
}
