import SwiftUI

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

    @State private var scannerError: String?

    public init(onResult: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onResult = onResult
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            scannerSurface
                .navigationTitle("Scan Pairing QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                }
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
