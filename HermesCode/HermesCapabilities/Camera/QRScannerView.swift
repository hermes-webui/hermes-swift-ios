import SwiftUI
import AVFoundation

/// SwiftUI wrapper around `QRScannerController`. Handles the permission gate so callers can drop this
/// directly into a sheet without preflight code.
///
/// Usage:
/// ```
/// .sheet(isPresented: $showScanner) {
///     QRScannerView(
///         onResult: { payload in
///             // decode + use
///             showScanner = false
///         },
///         onCancel: { showScanner = false }
///     )
/// }
/// ```
public struct QRScannerView: View {
    public let onResult: (String) -> Void
    public let onCancel: () -> Void

    @State private var permission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var scannerError: String?

    public init(onResult: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onResult = onResult
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Scan Pairing QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch permission {
        case .authorized:
            scannerSurface
        case .notDetermined:
            VStack(spacing: 16) {
                Text("Hermes needs camera access to scan the pairing QR shown by your Mac.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Allow Camera") {
                    Task {
                        let granted = await AVCaptureDevice.requestAccess(for: .video)
                        permission = granted ? .authorized : .denied
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        case .denied, .restricted:
            VStack(spacing: 16) {
                Text("Camera access is off for Hermes. Open Settings to allow it, or paste the pairing payload from your Mac instead.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                        .buttonStyle(.borderedProminent)
                }
                Button("Use payload instead", action: onCancel)
            }
            .padding()
        @unknown default:
            Text("Camera state is unknown.").padding()
        }
    }

    private var scannerSurface: some View {
        ZStack {
            QRScannerRepresentable(
                onResult: { value in
                    onResult(value)
                },
                onError: { err in
                    scannerError = err.localizedDescription
                }
            )
            .ignoresSafeArea(edges: .bottom)
            if let scannerError {
                VStack {
                    Spacer()
                    Text(scannerError)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
        }
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onResult: (String) -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let ctrl = QRScannerController()
        ctrl.onResult = { value in
            ctrl.pause()
            onResult(value)
        }
        ctrl.onError = onError
        return ctrl
    }

    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {}
}
