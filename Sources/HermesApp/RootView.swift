import SwiftUI
import HermesCore
import HermesBridge
import HermesWebView
import HermesUI

struct RootView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var session: SessionManager
    @State private var showingSettings = false

    private var bridge: JSBridge {
        JSBridge { session.activeClient }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HermesWebView(url: settings.webViewURL, bridge: bridge)
                .ignoresSafeArea()

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .padding(10)
                        .background(.thinMaterial, in: Circle())
                }
                ConnectionStatusView(session: session)
            }
            .padding()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings, session: session)
        }
    }
}
