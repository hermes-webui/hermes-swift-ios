import Foundation
import LocalAuthentication

public final class BiometricsCapability: Capability, @unchecked Sendable {
    public let name = "biometrics"

    public init() {}

    public func permissionStatus() async -> PermissionStatus {
        let ctx = LAContext()
        var error: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return .granted
        }
        if let err = error as? LAError {
            switch err.code {
            case .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet: return .restricted
            default: return .notDetermined
            }
        }
        return .notDetermined
    }

    public func requestPermission() async -> PermissionStatus {
        // Biometrics permission is granted at first evaluation, not by a separate prompt.
        return await permissionStatus()
    }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        switch method {
        case "authenticate":
            let reason = params["reason"]?.stringValue ?? "Authorize Hermes action"
            let ctx = LAContext()
            do {
                let success = try await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                return .object(["success": .bool(success)])
            } catch {
                throw CapabilityError.underlying(error.localizedDescription)
            }
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }
}
