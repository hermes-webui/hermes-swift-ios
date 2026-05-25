import Foundation
import WebKit

public enum WebViewConfiguration {

    /// Build the canonical `WKWebViewConfiguration` for the app web container.
    /// Registers exactly ONE script message handler: `"hermes"`. Do not add more — route everything
    /// through that single handler so the protocol stays a one-channel contract with the web client.
    public static func make(bridge: JSBridge) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        let userContent = WKUserContentController()

        // Single script message handler — all JS → native traffic flows through this.
        userContent.add(bridge, name: "hermes")

        // Inject the bridge stub so the web client can call window.hermes.invoke(...)
        // before any of its own scripts run.
        let stub = """
        (function() {
          if (window.hermes) return;
          const pending = new Map();
          let nextId = 1;

          window.hermes = {
            invoke(method, params) {
              return new Promise((resolve, reject) => {
                const id = "h-" + (nextId++);
                pending.set(id, { resolve, reject });
                window.webkit.messageHandlers.hermes.postMessage({ id, method, params: params || null });
              });
            },
            deliverResponse({ id, result, error }) {
              const p = pending.get(id);
              if (!p) return;
              pending.delete(id);
              if (error) reject(p, error); else resolve(p, result);
            }
          };

          function resolve(p, v) { p.resolve(v); }
          function reject(p, e) { p.reject(e); }
        })();
        """
        let userScript = WKUserScript(source: stub, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContent.addUserScript(userScript)

        let voiceMode = AppSettings.shared.voiceInputMode.rawValue
        let bgVoice = "true"
        let prefsScript = """
        window.hermesNativePreferences = {
          voiceInputMode: "\(voiceMode)",
          backgroundVoiceMode: \(bgVoice)
        };
        try { localStorage.setItem("hermes_voice_input_mode", "\(voiceMode)"); } catch (_) {}
        try { localStorage.setItem("hermes_background_voice_mode", "\(bgVoice)"); } catch (_) {}
        """
        let settingsUserScript = WKUserScript(source: prefsScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContent.addUserScript(settingsUserScript)

        config.userContentController = userContent
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        if #available(iOS 16.4, *) {
            config.preferences.isElementFullscreenEnabled = true
        }
        config.websiteDataStore = .default()
        return config
    }
}
