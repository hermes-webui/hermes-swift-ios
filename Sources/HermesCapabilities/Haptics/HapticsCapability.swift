import Foundation
import UIKit

/// Triggers iOS haptic feedback. No permission needed.
///
/// Methods:
///   - `impact`  — params: `{ style: "light" | "medium" | "heavy" | "soft" | "rigid" }`
///   - `notification` — params: `{ type: "success" | "warning" | "error" }`
///   - `selection` — no params; the brief "tick" used on picker scrolls
public final class HapticsCapability: Capability, @unchecked Sendable {
    public let name = "haptics"

    public init() {}

    public func permissionStatus() async -> PermissionStatus { .granted }
    public func requestPermission() async -> PermissionStatus { .granted }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        switch method {
        case "impact":
            let style: UIImpactFeedbackGenerator.FeedbackStyle = Self.impactStyle(params["style"]?.stringValue)
            await MainActor.run {
                let gen = UIImpactFeedbackGenerator(style: style)
                gen.prepare(); gen.impactOccurred()
            }
            return .null
        case "notification":
            let type: UINotificationFeedbackGenerator.FeedbackType = Self.notificationType(params["type"]?.stringValue)
            await MainActor.run {
                let gen = UINotificationFeedbackGenerator()
                gen.prepare(); gen.notificationOccurred(type)
            }
            return .null
        case "selection":
            await MainActor.run {
                let gen = UISelectionFeedbackGenerator()
                gen.prepare(); gen.selectionChanged()
            }
            return .null
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }

    private static func impactStyle(_ raw: String?) -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch raw {
        case "light":  return .light
        case "heavy":  return .heavy
        case "soft":   return .soft
        case "rigid":  return .rigid
        default:       return .medium
        }
    }

    private static func notificationType(_ raw: String?) -> UINotificationFeedbackGenerator.FeedbackType {
        switch raw {
        case "warning": return .warning
        case "error":   return .error
        default:        return .success
        }
    }
}
