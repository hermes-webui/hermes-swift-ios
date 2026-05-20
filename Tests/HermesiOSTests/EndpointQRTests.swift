import XCTest
@testable import HermesCore

final class EndpointQRTests: XCTestCase {

    func testRoundTripQRString() throws {
        let payload = EndpointQR.Payload(
            url: "https://hermes.tailnet.ts.net",
            displayName: "Home",
            leafCertFingerprint: "a1b2c3",
            bearerToken: "tk-xyz"
        )
        let encoded = try EndpointQR.encode(payload)
        XCTAssertTrue(encoded.hasPrefix("hermes:agent:v1:"))
        let decoded = try EndpointQR.decode(encoded)
        XCTAssertEqual(decoded, payload)
    }

    func testDecodesDeepLink() throws {
        let payload = EndpointQR.Payload(
            url: "http://hermes.local:8787",
            displayName: "LAN dev",
            leafCertFingerprint: nil,
            bearerToken: nil
        )
        let qr = try EndpointQR.encode(payload)
        let b64 = String(qr.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false)[3])
        let deepLink = "hermes://agent?payload=\(b64)"
        let decoded = try EndpointQR.decode(deepLink)
        XCTAssertEqual(decoded, payload)
    }

    func testEndpointConstruction() throws {
        let payload = EndpointQR.Payload(
            url: "https://example.com",
            displayName: "Example",
            leafCertFingerprint: "DEADBEEF",   // intentionally uppercase to test normalization
            bearerToken: nil
        )
        let endpoint = try EndpointQR.endpoint(from: payload)
        XCTAssertEqual(endpoint.url.absoluteString, "https://example.com")
        XCTAssertEqual(endpoint.displayName, "Example")
        XCTAssertEqual(endpoint.leafCertFingerprint, "deadbeef")
    }

    func testRejectsMalformed() {
        XCTAssertThrowsError(try EndpointQR.decode("garbage"))
        XCTAssertThrowsError(try EndpointQR.decode("hermes:agent:v99:abc"))
    }
}
