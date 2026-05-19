import Foundation
import UserNotifications

public final class NotificationsCapability: Capability, @unchecked Sendable {
    public let name = "notifications"

    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func permissionStatus() async -> PermissionStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:        return .notDetermined
        case .denied:               return .denied
        case .authorized, .provisional, .ephemeral: return .granted
        @unknown default:           return .notDetermined
        }
    }

    public func requestPermission() async -> PermissionStatus {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        guard await permissionStatus() == .granted else {
            if await requestPermission() != .granted { throw CapabilityError.permissionDenied }
        }
        switch method {
        case "schedule":
            guard let title = params["title"]?.stringValue else { throw CapabilityError.missingParam("title") }
            let body = params["body"]?.stringValue ?? ""
            let delay = params["delaySeconds"]?.intValue ?? 0

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger: UNNotificationTrigger? = delay > 0
                ? UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delay), repeats: false)
                : nil

            let id = UUID().uuidString
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try await center.add(request)
            return .object(["id": .string(id)])
        case "cancel":
            guard let id = params["id"]?.stringValue else { throw CapabilityError.missingParam("id") }
            center.removePendingNotificationRequests(withIdentifiers: [id])
            return .null
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }
}
