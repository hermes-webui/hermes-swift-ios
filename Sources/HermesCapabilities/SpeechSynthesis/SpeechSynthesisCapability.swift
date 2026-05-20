import Foundation
import AVFoundation

/// Text-to-speech via `AVSpeechSynthesizer`. No permission required (TTS doesn't touch the mic).
///
/// Methods:
///   - `speak`  — params: `{ text: String, language?: "en-US", rate?: Double (0..1), pitch?: Double (0.5..2.0) }`
///   - `stop`   — interrupts any current utterance
///   - `voices` — returns the list of available voice identifiers + languages
public final class SpeechSynthesisCapability: Capability, @unchecked Sendable {
    public let name = "speech"

    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public func permissionStatus() async -> PermissionStatus { .granted }
    public func requestPermission() async -> PermissionStatus { .granted }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        switch method {
        case "speak":
            guard let text = params["text"]?.stringValue else { throw CapabilityError.missingParam("text") }
            let utterance = AVSpeechUtterance(string: text)
            if let lang = params["language"]?.stringValue {
                utterance.voice = AVSpeechSynthesisVoice(language: lang)
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
            }
            if case let .double(rate) = params["rate"]?.value ?? .null {
                utterance.rate = Float(rate)
            }
            if case let .double(pitch) = params["pitch"]?.value ?? .null {
                utterance.pitchMultiplier = Float(pitch)
            }
            await MainActor.run { synthesizer.speak(utterance) }
            return .null
        case "stop":
            await MainActor.run { synthesizer.stopSpeaking(at: .immediate) }
            return .null
        case "voices":
            let voices = AVSpeechSynthesisVoice.speechVoices().map { v -> AnyCodable in
                .object([
                    "identifier": .string(v.identifier),
                    "language":   .string(v.language),
                    "name":       .string(v.name),
                    "quality":    .string(v.quality == .enhanced ? "enhanced" : "default"),
                ])
            }
            return .array(voices)
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }
}
