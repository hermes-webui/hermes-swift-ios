import XCTest
@testable import HermesBridge

final class QRPairingTests: XCTestCase {

    func testRoundTripQRString() throws {
        let payload = PairingPayload(
            deviceId: "mac-1",
            displayName: "Justin's MacBook Pro",
            host: "192.168.1.20",
            port: 8787,
            fingerprint: "abc123",
            deviceToken: "token-xyz",
            relayRoutingToken: "route-456"
        )
        let encoded = try QRPairing.encode(payload)
        XCTAssertTrue(encoded.hasPrefix("hermes:pair:v1:"))
        let decoded = try QRPairing.decode(encoded)
        XCTAssertEqual(decoded, payload)
    }

    func testDecodesDeepLinkForm() throws {
        let payload = PairingPayload(
            deviceId: "mac-2",
            displayName: "Studio",
            host: "10.0.0.5",
            port: 9000,
            fingerprint: "ff",
            deviceToken: "tk",
            relayRoutingToken: nil
        )
        let qr = try QRPairing.encode(payload)
        // The token piece after "hermes:pair:v1:" is the base64 payload.
        let b64 = String(qr.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false)[3])
        let deepLink = "hermes://pair?payload=\(b64)"
        let decoded = try QRPairing.decode(deepLink)
        XCTAssertEqual(decoded, payload)
    }

    func testRejectsMalformed() {
        XCTAssertThrowsError(try QRPairing.decode("garbage"))
        XCTAssertThrowsError(try QRPairing.decode("hermes:pair:v99:abc"))
    }
}
