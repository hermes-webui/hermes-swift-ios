import Foundation
import UIKit
import UserNotifications

/// Sets/clears the numeric badge on the app icon.
/// Uses `UNUserNotificationCenter.setBadgeCount` on iOS 16+ (the modern, non-deprecated API).
public final class AppBadgeCapability: Capability, @unchecked Sendable {
    public let name = "appBadge"

    public init() {}

    public func permissionStatus() async -> PermissionStatus { .granted }
    public func requestPermission() async -> PermissionStatus { .granted }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        switch method {
        case "set":
            guard let count = params["count"]?.intValue else { throw CapabilityError.missingParam("count") }
            try await UNUserNotificationCenter.current().setBadgeCount(max(0, count))
            return .null
        case "clear":
            try await UNUserNotificationCenter.current().setBadgeCount(0)
            return .null
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }
}
