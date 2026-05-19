import Foundation
import AVFoundation
import UIKit

public final class CameraCapability: Capability, @unchecked Sendable {
    public let name = "camera"

    public init() {}

    public func permissionStatus() async -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: return .notDetermined
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .authorized:    return .granted
        @unknown default:    return .notDetermined
        }
    }

    public func requestPermission() async -> PermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .granted : .denied
    }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        guard await permissionStatus() == .granted else {
            if await requestPermission() != .granted { throw CapabilityError.permissionDenied }
        }
        switch method {
        case "scanQR":
            let value = try await scanQRFromTopViewController()
            return .object(["payload": .string(value)])
        case "takePhoto":
            // TODO: present a UIImagePickerController / AVCaptureSession-backed flow,
            // return { dataURL: "data:image/jpeg;base64,..." } or a temporary file URL.
            throw CapabilityError.underlying("camera.takePhoto not yet implemented")
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }

    /// Headless-style QR scan: present `QRScannerController` modally on top of the current root view
    /// controller, await the first detected QR string, dismiss, and return the payload.
    /// Used by the JS bridge / Mac-initiated `capability.camera.scanQR` call. The in-app pairing flow
    /// uses `QRScannerView` directly in SwiftUI — same controller underneath.
    @MainActor
    private func scanQRFromTopViewController() async throws -> String {
        guard let host = Self.topViewController() else {
            throw CapabilityError.underlying("no view controller available to present scanner")
        }

        let controller = QRScannerController()
        let nav = UINavigationController(rootViewController: controller)
        controller.title = "Scan QR"

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            let finish: (Result<String, Error>) -> Void = { result in
                guard !finished else { return }
                finished = true
                nav.dismiss(animated: true)
                switch result {
                case .success(let value): continuation.resume(returning: value)
                case .failure(let err):   continuation.resume(throwing: err)
                }
            }

            let cancelItem = UIBarButtonItem(barButtonSystemItem: .cancel, primaryAction: UIAction { _ in
                finish(.failure(CapabilityError.underlying("user cancelled")))
            })
            controller.navigationItem.leftBarButtonItem = cancelItem

            controller.onResult = { value in
                controller.pause()
                finish(.success(value))
            }
            controller.onError = { err in
                finish(.failure(CapabilityError.underlying(err.localizedDescription)))
            }

            host.present(nav, animated: true)
        }
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let root = scenes.first?.keyWindow?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
