import XCTest
@testable import HermesBridge

final class MessageCodingTests: XCTestCase {

    func testCommandRequestRoundTrip() throws {
        let msg = Message(
            id: "abc",
            protocolVersion: BridgeProtocol.currentVersion,
            kind: .commandRequest,
            payload: .commandRequest(.init(
                command: CommandRequest.WellKnown.runAgentPrompt,
                params: .object(["prompt": .string("hello")])
            ))
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        XCTAssertEqual(decoded, msg)
    }

    func testEventRoundTrip() throws {
        let msg = Message(
            id: "e1",
            protocolVersion: 1,
            kind: .event,
            payload: .event(.init(topic: EventPayload.WellKnownTopic.agentLog,
                                  body: .object(["line": .string("hi"), "level": .string("info")])))
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        XCTAssertEqual(decoded, msg)
    }

    func testErrorPayload() throws {
        let msg = Message(
            id: "err",
            protocolVersion: 1,
            kind: .error,
            payload: .error(.init(code: BridgeError.unknownCommand,
                                  message: "agent.bogus is not a command",
                                  inReplyTo: "abc"))
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        XCTAssertEqual(decoded, msg)
    }

    func testUnsupportedVersionIsDetected() {
        XCTAssertFalse(BridgeProtocol.supportedVersions.contains(0))
        XCTAssertFalse(BridgeProtocol.supportedVersions.contains(99))
        XCTAssertTrue(BridgeProtocol.supportedVersions.contains(BridgeProtocol.currentVersion))
    }
}
