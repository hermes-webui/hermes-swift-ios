import XCTest
@testable import HermesCapabilities

final class CapabilityRegistryTests: XCTestCase {

    func testDefaultRegistrationSurfacesAllNames() async {
        let reg = CapabilityRegistry()
        await reg.registerDefaults()
        let names = await reg.allNames()
        // Defaults intentionally exclude Location and Contacts pending App Store review readiness — see CapabilityRegistry.swift.
        XCTAssertEqual(Set(names), Set(["camera", "notifications", "share", "biometrics"]))
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
