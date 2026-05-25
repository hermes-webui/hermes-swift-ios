import Foundation
import UIKit

/// Read-only device + locale information. No permission required.
/// Battery monitoring is opt-in for the lifetime of UIDevice; we toggle it briefly to read state.
public final class DeviceInfoCapability: Capability, @unchecked Sendable {
    public let name = "deviceInfo"

    public init() {}

    public func permissionStatus() async -> PermissionStatus { .granted }
    public func requestPermission() async -> PermissionStatus { .granted }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        switch method {
        case "get":
            return await MainActor.run { Self.snapshot() }
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }

    @MainActor
    private static func snapshot() -> AnyCodable {
        let device = UIDevice.current
        let wasMonitoring = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true
        defer { device.isBatteryMonitoringEnabled = wasMonitoring }

        let batteryLevel: AnyCodable = device.batteryLevel >= 0
            ? .double(Double(device.batteryLevel))
            : .null
        let batteryStateLabel: String = {
            switch device.batteryState {
            case .charging: return "charging"
            case .full:     return "full"
            case .unplugged: return "unplugged"
            default:        return "unknown"
            }
        }()

        let info: [String: AnyCodable] = [
            "model":          .string(device.model),
            "name":           .string(device.name),
            "systemName":     .string(device.systemName),
            "systemVersion":  .string(device.systemVersion),
            "identifierForVendor": .string(device.identifierForVendor?.uuidString ?? ""),
            "userInterfaceIdiom": .string(Self.idiomLabel(device.userInterfaceIdiom)),
            "batteryLevel":   batteryLevel,
            "batteryState":   .string(batteryStateLabel),
            "locale":         .string(Locale.current.identifier),
            "timeZone":       .string(TimeZone.current.identifier),
            "languageCode":   .string(Locale.current.language.languageCode?.identifier ?? ""),
            "isLowPowerMode": .bool(ProcessInfo.processInfo.isLowPowerModeEnabled),
        ]
        return .object(info)
    }

    private static func idiomLabel(_ idiom: UIUserInterfaceIdiom) -> String {
        switch idiom {
        case .phone: return "phone"
        case .pad:   return "pad"
        case .mac:   return "mac"
        case .tv:    return "tv"
        case .carPlay: return "carPlay"
        case .vision: return "vision"
        default:     return "unspecified"
        }
    }
}
