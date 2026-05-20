import Foundation
import UIKit

/// Read/write the iOS general pasteboard.
/// No permission required, but iOS shows a system pasteboard-access notification on read in newer OS versions —
/// that's expected behaviour, not something to suppress.
public final class ClipboardCapability: Capability, @unchecked Sendable {
    public let name = "clipboard"

    public init() {}

    public func permissionStatus() async -> PermissionStatus { .granted }
    public func requestPermission() async -> PermissionStatus { .granted }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        switch method {
        case "read":
            let value = await MainActor.run { UIPasteboard.general.string ?? "" }
            return .object(["value": .string(value)])
        case "write":
            guard let value = params["value"]?.stringValue else { throw CapabilityError.missingParam("value") }
            await MainActor.run { UIPasteboard.general.string = value }
            return .null
        case "clear":
            await MainActor.run { UIPasteboard.general.items = [] }
            return .null
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }
}
