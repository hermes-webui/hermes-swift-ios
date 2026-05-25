import Foundation
import AVFoundation
import UIKit

public final class CameraCapability: NSObject, Capability, @unchecked Sendable, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public let name = "camera"
    private var pendingPhotoContinuation: CheckedContinuation<CapabilityResult, Error>?
    private var photoPickerHost: UIViewController?
    private var pendingPhotoJpegQuality: CGFloat = 0.9
    private var pendingIncludeDataURL = true

    public override init() {
        super.init()
    }

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
        if await permissionStatus() != .granted,
           await requestPermission() != .granted {
            throw CapabilityError.permissionDenied
        }
        switch method {
        case "scanQR":
            let value = try await scanQRFromTopViewController()
            return .object(["payload": .string(value)])
        case "takePhoto":
            return try await takePhotoFromTopViewController(params: params)
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

            let cancelAction = UIAction { _ in
                finish(.failure(CapabilityError.underlying("user cancelled")))
            }
            let cancelItem = UIBarButtonItem(systemItem: .cancel, primaryAction: cancelAction)
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

    @MainActor
    private func takePhotoFromTopViewController(params: CapabilityParams) async throws -> CapabilityResult {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            throw CapabilityError.underlying("camera source is not available on this device")
        }
        guard pendingPhotoContinuation == nil else {
            throw CapabilityError.underlying("camera.takePhoto is already in progress")
        }
        guard let host = Self.topViewController() else {
            throw CapabilityError.underlying("no view controller available to present camera")
        }

        let quality: CGFloat = {
            if case let .double(v) = params["jpegQuality"]?.value ?? .null {
                return min(max(CGFloat(v), 0.1), 1.0)
            }
            return 0.9
        }()

        let includeDataURL: Bool = {
            if case let .bool(v) = params["includeDataURL"]?.value ?? .null { return v }
            return true
        }()

        return try await withCheckedThrowingContinuation { continuation in
            pendingPhotoContinuation = continuation
            photoPickerHost = host
            pendingPhotoJpegQuality = quality
            pendingIncludeDataURL = includeDataURL

            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.modalPresentationStyle = .fullScreen
            picker.delegate = self

            host.present(picker, animated: true)
        }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        pendingPhotoContinuation?.resume(throwing: CapabilityError.underlying("user cancelled"))
        pendingPhotoContinuation = nil
        photoPickerHost = nil
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        defer {
            pendingPhotoContinuation = nil
            photoPickerHost = nil
        }

        picker.dismiss(animated: true)

        guard let image = (info[.originalImage] as? UIImage) ?? (info[.editedImage] as? UIImage) else {
            pendingPhotoContinuation?.resume(throwing: CapabilityError.underlying("failed to capture image"))
            return
        }

        guard let jpegData = image.jpegData(compressionQuality: pendingPhotoJpegQuality) else {
            pendingPhotoContinuation?.resume(throwing: CapabilityError.underlying("failed to encode JPEG"))
            return
        }

        var obj: [String: AnyCodable] = [
            "mimeType": .string("image/jpeg"),
            "sizeBytes": .int(jpegData.count)
        ]
        if pendingIncludeDataURL {
            obj["dataURL"] = .string("data:image/jpeg;base64,\(jpegData.base64EncodedString())")
        }
        pendingPhotoContinuation?.resume(returning: .object(obj))
    }
}
