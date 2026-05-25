import Foundation
import AVFoundation
import Combine

@MainActor
final class RealtimeVoiceSessionManager: ObservableObject {
    static let shared = RealtimeVoiceSessionManager()

    enum State: Equatable {
        case idle
        case connecting
        case active
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastTranscript: String = ""
    @Published private(set) var lastAssistantText: String = ""

    private let wsSession = URLSession(configuration: .default)
    private var wsTask: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private static let defaultRealtimePath = "/api/voice/session"

    private init() {}

    func start(for endpoint: HermesEndpoint) {
        guard case .idle = state else { return }
        guard let wsURL = Self.makeWebSocketURL(from: endpoint.url, path: Self.defaultRealtimePath) else {
            state = .failed("Invalid realtime endpoint path")
            return
        }

        state = .connecting
        lastTranscript = ""
        lastAssistantText = ""

        do {
            try configureAudioSession()
            try startCapture()
        } catch {
            state = .failed("Audio start failed: \(error.localizedDescription)")
            return
        }

        let task = wsSession.webSocketTask(with: wsURL)
        wsTask = task
        task.resume()

        state = .active
        receiveLoop()
    }

    func stop() {
        stopCapture()
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        state = .idle
    }

    private static func makeWebSocketURL(from baseURL: URL, path: String) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        if components.scheme == "https" { components.scheme = "wss" }
        if components.scheme == "http" { components.scheme = "ws" }
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = normalizedPath
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .allowBluetoothA2DP, .duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startCapture() throws {
        let input = audioEngine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            guard let data = Self.pcm16Data(from: buffer) else { return }
            let payload: [String: Any] = [
                "type": "audio_chunk",
                "format": "pcm16le",
                "sample_rate": Int(inputFormat.sampleRate),
                "channels": Int(inputFormat.channelCount),
                "data": data.base64EncodedString()
            ]
            self.sendJSON(payload)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func stopCapture() {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func pcm16Data(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)
        var out = Data(capacity: frames * channels * MemoryLayout<Int16>.size)

        for frame in 0..<frames {
            for ch in 0..<channels {
                let sample = channelData[ch][frame]
                let clamped = max(-1.0, min(1.0, sample))
                var int16 = Int16(clamped * Float(Int16.max))
                withUnsafeBytes(of: &int16) { bytes in
                    out.append(contentsOf: bytes)
                }
            }
        }
        return out
    }

    private func sendJSON(_ object: [String: Any]) {
        guard let wsTask else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return }
        wsTask.send(.string(text)) { [weak self] error in
            guard let self else { return }
            if let error {
                Task { @MainActor in
                    self.state = .failed("Send failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func receiveLoop() {
        wsTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                Task { @MainActor in
                    self.state = .failed("Receive failed: \(error.localizedDescription)")
                    self.stop()
                }
            case .success(let message):
                Task { @MainActor in
                    self.handleIncoming(message)
                    if case .active = self.state {
                        self.receiveLoop()
                    }
                }
            }
        }
    }

    private func handleIncoming(_ message: URLSessionWebSocketTask.Message) {
        let text: String
        switch message {
        case .string(let s):
            text = s
        case .data(let data):
            text = String(data: data, encoding: .utf8) ?? ""
        @unknown default:
            return
        }
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        guard let type = obj["type"] as? String else { return }

        switch type {
        case "transcript_partial", "transcript_final":
            if let t = obj["text"] as? String { lastTranscript = t }
        case "assistant_text":
            if let t = obj["text"] as? String { lastAssistantText = t }
        case "error":
            let msg = (obj["message"] as? String) ?? "Realtime error"
            state = .failed(msg)
            stop()
        default:
            break
        }
    }
}
