import SwiftUI
import HermesCore
import HermesWebView
import HermesUI

struct RootView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: EndpointStore
    @State private var showingSettings = false

    private var bridge: JSBridge { JSBridge() }

    var body: some View {
        Group {
            if let active = store.activeEndpoint {
                webShell(for: active)
            } else {
                ConnectHeroView(store: store)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store)
        }
    }

    private func webShell(for endpoint: HermesEndpoint) -> some View {
        ZStack(alignment: .topTrailing) {
            HermesWebView(endpoint: endpoint, bridge: bridge)
                .ignoresSafeArea()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
            .padding()
        }
    }
}
