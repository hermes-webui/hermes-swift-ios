import XCTest
@testable import HermesBridge

final class TokenRotationTests: XCTestCase {

    func testAuthRotatedRoundTripsThroughMessage() throws {
        let msg = Message(
            id: "rot-1",
            protocolVersion: BridgeProtocol.currentVersion,
            kind: .authRotated,
            payload: .authRotated(AuthRotated(
                newDeviceToken: "fresh-token-xyz",
                oldTokenValidUntil: "2026-05-19T20:00:00Z"
            ))
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        XCTAssertEqual(decoded, msg)
    }

    func testAuthRotatedWithoutGracePeriod() throws {
        let msg = Message(
            id: "rot-2",
            protocolVersion: 1,
            kind: .authRotated,
            payload: .authRotated(AuthRotated(newDeviceToken: "tk"))
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        if case .authRotated(let rot) = decoded.payload {
            XCTAssertEqual(rot.newDeviceToken, "tk")
            XCTAssertNil(rot.oldTokenValidUntil)
        } else {
            XCTFail("expected authRotated payload")
        }
    }
}
