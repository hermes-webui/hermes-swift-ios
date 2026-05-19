import SwiftUI
import HermesBridge

public struct ConnectionStatusView: View {
    @ObservedObject public var session: SessionManager

    public init(session: SessionManager = .shared) { self.session = session }

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }

    private var color: Color {
        switch session.activeClient?.status {
        case .connected: return .green
        case .connecting: return .yellow
        case .failed: return .red
        default: return .gray
        }
    }

    private var label: String {
        switch session.activeClient?.status {
        case .some(.connected(let via)): return "Connected via \(via)"
        case .some(.connecting):         return "Connecting…"
        case .some(.failed(let msg)):    return "Failed: \(msg)"
        case .some(.disconnected), .none: return session.pairedDevices.isEmpty ? "No Mac paired" : "Disconnected"
        }
    }
}
