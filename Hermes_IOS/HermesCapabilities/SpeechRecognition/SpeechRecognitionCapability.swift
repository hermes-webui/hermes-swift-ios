import Foundation
import AVFoundation
import Speech

/// Speech-to-text via Apple's on-device/cloud recognizer.
///
/// Methods:
///   - `transcribeOnce` — params: `{ locale?: "en-US", timeoutSeconds?: Double }`
///                       returns: `{ text: String }`
///   - `stop`          — params: `{}`
///                       returns: `{ stopped: true }`
public final class SpeechRecognitionCapability: Capability, @unchecked Sendable {
    public let name = "speechRecognition"

    private let queue = DispatchQueue(label: "SpeechRecognitionCapability")
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    public init() {}

    public func permissionStatus() async -> PermissionStatus {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micGranted = Self.microphoneAuthorizationStatus() == .granted
        switch speechStatus {
        case .authorized:
            return micGranted ? .granted : .denied
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }

    public func requestPermission() async -> PermissionStatus {
        let speechAuth = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechAuth == .authorized else {
            return speechAuth == .notDetermined ? .notDetermined : .denied
        }

        let micGranted = await Self.requestMicrophonePermission()
        return micGranted ? .granted : .denied
    }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        switch method {
        case "transcribeOnce":
            if await permissionStatus() != .granted,
               await requestPermission() != .granted {
                throw CapabilityError.permissionDenied
            }

            let localeID = params["locale"]?.stringValue ?? Locale.current.identifier
            let timeoutSeconds: TimeInterval = {
                if case let .double(v) = params["timeoutSeconds"]?.value ?? .null {
                    return min(max(v, 2.0), 30.0)
                }
                return 8.0
            }()

            let text = try await startSingleTranscription(localeID: localeID, timeoutSeconds: timeoutSeconds)
            return .object(["text": .string(text)])
        case "stop":
            try await stopRecognition()
            return .object(["stopped": .bool(true)])
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }

    private func startSingleTranscription(localeID: String, timeoutSeconds: TimeInterval) async throws -> String {
        try await stopRecognition()

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID)), recognizer.isAvailable else {
            throw CapabilityError.underlying("speech recognizer unavailable for locale \(localeID)")
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return }

                let engine = AVAudioEngine()
                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true

                self.audioEngine = engine
                self.recognitionRequest = request

                var settled = false
                var bestText = ""

                let settle: (Result<String, Error>) -> Void = { result in
                    guard !settled else { return }
                    settled = true
                    self.queue.async {
                        self.stopRecognitionInternal()
                    }
                    switch result {
                    case .success(let text):
                        continuation.resume(returning: text)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }

                self.recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                    if let result {
                        bestText = result.bestTranscription.formattedString
                        if result.isFinal {
                            let finalText = bestText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if finalText.isEmpty {
                                settle(.failure(CapabilityError.underlying("no speech recognized")))
                            } else {
                                settle(.success(finalText))
                            }
                            return
                        }
                    }
                    if let error {
                        settle(.failure(CapabilityError.underlying(error.localizedDescription)))
                    }
                }

                let inputNode = engine.inputNode
                let format = inputNode.outputFormat(forBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    request.append(buffer)
                }

                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .allowBluetoothA2DP, .duckOthers])
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                    engine.prepare()
                    try engine.start()
                } catch {
                    settle(.failure(CapabilityError.underlying("failed to start audio capture: \(error.localizedDescription)")))
                    return
                }

                self.queue.asyncAfter(deadline: .now() + timeoutSeconds) {
                    guard !settled else { return }
                    let text = bestText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if text.isEmpty {
                        settle(.failure(CapabilityError.underlying("speech timed out")))
                    } else {
                        settle(.success(text))
                    }
                }
            }
        }
    }

    private func stopRecognition() async throws {
        await withCheckedContinuation { continuation in
            queue.async {
                self.stopRecognitionInternal()
                continuation.resume()
            }
        }
    }

    private func stopRecognitionInternal() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            if engine.isRunning { engine.stop() }
        }
        audioEngine = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ignore deactivation failures.
        }
    }

    private static func microphoneAuthorizationStatus() -> PermissionStatus {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    private static func microphoneGrantedPrompt() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func requestMicrophonePermission() async -> Bool {
        if microphoneAuthorizationStatus() == .granted { return true }
        return await microphoneGrantedPrompt()
    }
}
