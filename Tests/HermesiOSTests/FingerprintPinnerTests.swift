import XCTest
@testable import HermesCore

final class FingerprintPinnerTests: XCTestCase {

    func testFingerprintIsLowercaseHexSHA256() {
        let data = Data("hello".utf8)
        let fp = FingerprintPinner.fingerprint(ofDER: data)
        // SHA-256("hello")
        XCTAssertEqual(fp, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        XCTAssertEqual(fp.count, 64)
    }

    func testExpectedFingerprintNormalizedToLowercase() {
        let pinner = FingerprintPinner(expectedFingerprint: "ABCDEF1234")
        XCTAssertEqual(pinner.expectedFingerprint, "abcdef1234")
    }
}
