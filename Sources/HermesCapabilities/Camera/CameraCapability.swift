import Foundation
import AVFoundation

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
        case "takePhoto":
            // TODO: present a UIImagePickerController / AVCaptureSession-backed flow,
            // return { dataURL: "data:image/jpeg;base64,..." } or a temporary file URL.
            throw CapabilityError.underlying("camera.takePhoto not yet implemented")
        case "scanQR":
            // TODO: AVCaptureSession + AVCaptureMetadataOutput for QR scanning,
            // intended primarily for pairing — see HermesUI/PairingView.
            throw CapabilityError.underlying("camera.scanQR not yet implemented")
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }
}
