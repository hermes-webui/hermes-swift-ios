import Foundation
import CoreLocation

public final class LocationCapability: NSObject, Capability, @unchecked Sendable, CLLocationManagerDelegate {
    public let name = "location"

    private let manager = CLLocationManager()
    private var permissionContinuation: CheckedContinuation<PermissionStatus, Never>?
    private var oneShotContinuation: CheckedContinuation<CLLocation, Error>?

    public override init() {
        super.init()
        manager.delegate = self
    }

    public func permissionStatus() async -> PermissionStatus {
        switch manager.authorizationStatus {
        case .notDetermined:                    return .notDetermined
        case .denied:                           return .denied
        case .restricted:                       return .restricted
        case .authorizedWhenInUse, .authorizedAlways: return .granted
        @unknown default:                       return .notDetermined
        }
    }

    public func requestPermission() async -> PermissionStatus {
        if manager.authorizationStatus != .notDetermined { return await permissionStatus() }
        return await withCheckedContinuation { cont in
            self.permissionContinuation = cont
            self.manager.requestWhenInUseAuthorization()
        }
    }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        guard await permissionStatus() == .granted else {
            if await requestPermission() != .granted { throw CapabilityError.permissionDenied }
        }
        switch method {
        case "getCurrent":
            let loc = try await getCurrentLocation()
            return .object([
                "latitude":  .double(loc.coordinate.latitude),
                "longitude": .double(loc.coordinate.longitude),
                "accuracy":  .double(loc.horizontalAccuracy),
                "timestamp": .double(loc.timestamp.timeIntervalSince1970),
            ])
        case "startUpdates":
            // TODO: stream updates back to the bridge via events.
            throw CapabilityError.underlying("location.startUpdates not yet implemented")
        case "stopUpdates":
            manager.stopUpdatingLocation()
            return .null
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }

    private func getCurrentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            self.oneShotContinuation = cont
            self.manager.requestLocation()
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if let cont = permissionContinuation {
            permissionContinuation = nil
            Task { cont.resume(returning: await permissionStatus()) }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last, let cont = oneShotContinuation {
            oneShotContinuation = nil
            cont.resume(returning: loc)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let cont = oneShotContinuation {
            oneShotContinuation = nil
            cont.resume(throwing: error)
        }
    }
}
