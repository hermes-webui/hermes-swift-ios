import SwiftUI

struct RootView: View {
    private enum LauncherUX {
        static let holdToDragSeconds: TimeInterval = 0.25
        static let tapSlop: CGFloat = 8
        static let minXRatio: CGFloat = 0.06
        static let maxXRatio: CGFloat = 0.94
        static let minYRatio: CGFloat = 0.10
        static let maxYRatio: CGFloat = 0.90
        static let edgeInset: CGFloat = 26
    }

    @EnvironmentObject var store: EndpointStore
    @State private var showingSettings = false
    @State private var launcherXRatio: CGFloat = 0.96
    @State private var launcherYRatio: CGFloat = 0.27
    @State private var launcherTouchStart: CFTimeInterval?
    @State private var launcherIsDragging = false
    @State private var bridge = JSBridge()

    var body: some View {
        ZStack {
            if let active = store.activeEndpoint {
                HermesWebView(endpoint: active, bridge: bridge, reconnectGeneration: store.connectionEpoch)
                    .id("\(active.url.absoluteString)|\(store.connectionEpoch)")
                    .ignoresSafeArea()

                launcherOverlay
            } else {
                SettingsView(store: store, connectionOnly: true)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store, connectionOnly: false) {
                showingSettings = false
            }
        }
    }

    private var launcherOverlay: some View {
        ZStack {
            // While touching/dragging the launcher, absorb all gestures behind it.
            if launcherTouchStart != nil || launcherIsDragging {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .zIndex(1)
            }

            GeometryReader { geo in
                ZStack {
                    Color.clear
                        .frame(width: 44, height: 44)
                    Image(systemName: "gearshape")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                }
                .contentShape(Rectangle())
                .position(
                    x: geo.size.width * launcherXRatio,
                    y: geo.size.height * launcherYRatio
                )
                .highPriorityGesture(repositionGesture(in: geo.size, safeTop: geo.safeAreaInsets.top, safeBottom: geo.safeAreaInsets.bottom))
                .zIndex(2)
            }
        }
    }

    private func repositionGesture(in size: CGSize, safeTop: CGFloat, safeBottom: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if launcherTouchStart == nil {
                    launcherTouchStart = CACurrentMediaTime()
                }

                // Require a short hold before drag to avoid accidental moves.
                guard holdElapsed() >= LauncherUX.holdToDragSeconds else { return }
                launcherIsDragging = true

                let clamped = clampLauncherPoint(value.location, in: size, safeTop: safeTop, safeBottom: safeBottom)
                launcherXRatio = clamped.x / max(size.width, 1)
                launcherYRatio = clamped.y / max(size.height, 1)
            }
            .onEnded { value in
                let holdTime = holdElapsed()
                let moveDistance = hypot(value.translation.width, value.translation.height)

                // Treat quick touch as a normal tap to open settings.
                if holdTime < LauncherUX.holdToDragSeconds && moveDistance < LauncherUX.tapSlop {
                    showingSettings = true
                }

                // If user held long enough but moved very little, still commit final point.
                if holdTime >= LauncherUX.holdToDragSeconds {
                    let clamped = clampLauncherPoint(value.location, in: size, safeTop: safeTop, safeBottom: safeBottom)
                    launcherXRatio = clamped.x / max(size.width, 1)
                    launcherYRatio = clamped.y / max(size.height, 1)
                }

                launcherTouchStart = nil
                launcherIsDragging = false
            }
    }

    private func holdElapsed() -> CFTimeInterval {
        guard let start = launcherTouchStart else { return 0 }
        return CACurrentMediaTime() - start
    }

    private func clampLauncherPoint(_ point: CGPoint, in size: CGSize, safeTop: CGFloat, safeBottom: CGFloat) -> CGPoint {
        let minX = size.width * LauncherUX.minXRatio
        let maxX = size.width * LauncherUX.maxXRatio
        let minY = max(size.height * LauncherUX.minYRatio, safeTop + LauncherUX.edgeInset)
        let maxY = min(size.height * LauncherUX.maxYRatio, size.height - safeBottom - LauncherUX.edgeInset)
        let clampedX = min(max(point.x, minX), maxX)
        let clampedY = min(max(point.y, minY), maxY)
        return CGPoint(x: clampedX, y: clampedY)
    }

}
