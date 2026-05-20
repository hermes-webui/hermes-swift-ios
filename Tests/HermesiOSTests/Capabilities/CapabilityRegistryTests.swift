import XCTest
@testable import HermesCapabilities

final class CapabilityRegistryTests: XCTestCase {

    func testDefaultRegistrationSurfacesAllNames() async {
        let reg = CapabilityRegistry()
        await reg.registerDefaults()
        let names = await reg.allNames()
        // Defaults intentionally exclude Location and Contacts pending App Store review readiness — see CapabilityRegistry.swift.
        let expected: Set<String> = [
            "camera", "biometrics", "notifications", "share",
            "clipboard", "haptics", "deviceInfo", "openURL",
            "appBadge", "speech", "qrGenerator", "documentPicker",
        ]
        XCTAssertEqual(Set(names), expected)
    }

    func testLookupReturnsRegisteredCapability() async {
        let reg = CapabilityRegistry()
        await reg.registerDefaults()
        let cam = await reg.capability(named: "camera")
        XCTAssertNotNil(cam)
        XCTAssertEqual(cam?.name, "camera")
    }

    func testUnknownCapabilityIsNil() async {
        let reg = CapabilityRegistry()
        await reg.registerDefaults()
        let none = await reg.capability(named: "bogus")
        XCTAssertNil(none)
    }
}
