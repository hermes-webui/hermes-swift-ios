import Foundation
import UIKit

/// Opens a URL via `UIApplication.open(_:options:completionHandler:)`. The OS gates which schemes are allowed
/// (`tel:`, `sms:`, `mailto:`, `maps:`, `https:` etc.). No permission needed.
public final class OpenURLCapability: Capability, @unchecked Sendable {
    public let name = "openURL"

    public init() {}

    public func permissionStatus() async -> PermissionStatus { .granted }
    public func requestPermission() async -> PermissionStatus { .granted }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        switch method {
        case "open":
            guard let urlString = params["url"]?.stringValue,
                  let url = URL(string: urlString) else {
                throw CapabilityError.missingParam("url")
            }
            let opened = await MainActor.run {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    return true
                }
                return false
            }
            return .object(["opened": .bool(opened)])
        case "canOpen":
            guard let urlString = params["url"]?.stringValue,
                  let url = URL(string: urlString) else {
                throw CapabilityError.missingParam("url")
            }
            let can = await MainActor.run { UIApplication.shared.canOpenURL(url) }
            return .object(["canOpen": .bool(can)])
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }
}
