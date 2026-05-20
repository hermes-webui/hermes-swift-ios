import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Generates a QR code from a string using CoreImage. Returns a base64-encoded PNG.
/// Useful for the inverse of `camera.scanQR` — the agent shows a QR back to the user
/// (share an endpoint, hand off a config, etc.). No permission required.
public final class QRGeneratorCapability: Capability, @unchecked Sendable {
    public let name = "qrGenerator"

    public init() {}

    public func permissionStatus() async -> PermissionStatus { .granted }
    public func requestPermission() async -> PermissionStatus { .granted }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        switch method {
        case "generate":
            guard let payload = params["payload"]?.stringValue else { throw CapabilityError.missingParam("payload") }
            let pixelSize: CGFloat = {
                if case let .int(v) = params["pixelSize"]?.value ?? .null { return CGFloat(v) }
                return 512
            }()
            let correction = params["correction"]?.stringValue ?? "M"  // L, M, Q, H

            guard let dataURL = renderPNGDataURL(payload: payload, pixelSize: pixelSize, correction: correction) else {
                throw CapabilityError.underlying("QR rendering failed")
            }
            return .object(["dataURL": .string(dataURL)])
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }

    private func renderPNGDataURL(payload: String, pixelSize: CGFloat, correction: String) -> String? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = correction
        guard let outputImage = filter.outputImage else { return nil }

        let scale = max(1, pixelSize / outputImage.extent.width)
        let scaled = outputImage.transformed(by: .init(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        let uiImage = UIImage(cgImage: cgImage)
        guard let pngData = uiImage.pngData() else { return nil }
        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }
}
