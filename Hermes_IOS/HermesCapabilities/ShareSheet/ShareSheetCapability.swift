import Foundation
import UIKit

public final class ShareSheetCapability: Capability, @unchecked Sendable {
    public let name = "share"

    public init() {}

    public func permissionStatus() async -> PermissionStatus { .granted }   // no permission needed
    public func requestPermission() async -> PermissionStatus { .granted }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        switch method {
        case "present":
            var items: [Any] = []
            if let text = params["text"]?.stringValue { items.append(text) }
            if let urlString = params["url"]?.stringValue, let url = URL(string: urlString) { items.append(url) }
            guard !items.isEmpty else { throw CapabilityError.missingParam("text or url") }

            await MainActor.run {
                let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
                Self.topViewController()?.present(activity, animated: true)
            }
            return .null
        default:
            throw CapabilityError.unknownMethod(method)
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
