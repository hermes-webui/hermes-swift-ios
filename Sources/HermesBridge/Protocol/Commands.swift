import Foundation

/// Typed command catalog — every command iOS can ask the Mac to perform lives here.
/// Extend by adding a case + matching encoder/decoder on the Mac side.
public struct CommandRequest: Codable, Sendable, Equatable {
    public let command: String
    public let params: JSONValue?

    public init(command: String, params: JSONValue? = nil) {
        self.command = command
        self.params = params
    }

    /// Reserved command names — keep in sync with the Mac BridgeServer's handler table.
    public enum WellKnown {
        public static let runAgentPrompt   = "agent.runPrompt"        // params: { prompt: String, conversationId?: String }
        public static let cancelAgentRun   = "agent.cancelRun"        // params: { runId: String }
        public static let getAgentState    = "agent.getState"         // params: nil
        public static let openWebViewURL   = "webview.openURL"        // params: { url: String }
        public static let reloadWebView    = "webview.reload"
        public static let setPreference    = "settings.set"           // params: { key: String, value: JSONValue }
        public static let getPreference    = "settings.get"           // params: { key: String }
        public static let listConversations = "agent.listConversations"
    }
}

public struct CommandResponse: Codable, Sendable, Equatable {
    public let inReplyTo: String
    public let result: JSONValue?
    public let error: BridgeError?

    public init(inReplyTo: String, result: JSONValue? = nil, error: BridgeError? = nil) {
        self.inReplyTo = inReplyTo
        self.result = result
        self.error = error
    }
}

/// Server → Client push.
public struct EventPayload: Codable, Sendable, Equatable {
    public let topic: String
    public let body: JSONValue

    public init(topic: String, body: JSONValue) {
        self.topic = topic
        self.body = body
    }

    public enum WellKnownTopic {
        public static let agentLog      = "agent.log"           // body: { line: String, level: String }
        public static let agentRunDelta = "agent.run.delta"     // body: { runId: String, delta: String }
        public static let agentRunDone  = "agent.run.done"      // body: { runId: String, finalText: String }
        public static let stateChanged  = "state.changed"
    }
}

/// Mac asks iPhone to invoke a native capability (e.g. take a photo).
public struct CapabilityRequest: Codable, Sendable, Equatable {
    public let capability: String   // e.g. "camera"
    public let method: String       // e.g. "takePhoto"
    public let params: JSONValue?

    public init(capability: String, method: String, params: JSONValue? = nil) {
        self.capability = capability
        self.method = method
        self.params = params
    }
}

public struct CapabilityResponse: Codable, Sendable, Equatable {
    public let inReplyTo: String
    public let result: JSONValue?
    public let error: BridgeError?

    public init(inReplyTo: String, result: JSONValue? = nil, error: BridgeError? = nil) {
        self.inReplyTo = inReplyTo
        self.result = result
        self.error = error
    }
}
