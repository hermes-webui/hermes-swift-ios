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

        // iOS WKWebView speech-recognition shim:
        // expose a SpeechRecognition-like surface backed by native capability.speechRecognition.transcribeOnce.
        // This gives webui a reliable STT path when browser speech APIs are missing/partial on iPhone.
        let speechShim = """
        (function() {
          if (window.SpeechRecognition || window.webkitSpeechRecognition) return;
          if (!window.hermes || typeof window.hermes.invoke !== "function") return;

          class HermesSpeechRecognition {
            constructor() {
              this.lang = (navigator.language || "en-US");
              this.continuous = false;
              this.onstart = null;
              this.onresult = null;
              this.onerror = null;
              this.onend = null;
              this._active = false;
            }

            start() {
              if (this._active) return;
              this._active = true;
              this._emit(this.onstart, { type: "start" });

              const runOnce = async () => {
                try {
                  const result = await window.hermes.invoke("capability.speechRecognition.transcribeOnce", {
                    locale: this.lang || "en-US",
                    timeoutSeconds: 8
                  });
                  if (!this._active) return;
                  const text = (result && result.text) ? String(result.text) : "";
                  if (text) {
                    const event = this._makeResultEvent(text);
                    this._emit(this.onresult, event);
                  } else {
                    this._emit(this.onerror, { type: "error", error: "no-speech" });
                  }
                } catch (e) {
                  if (!this._active) return;
                  this._emit(this.onerror, { type: "error", error: "network", message: String(e || "speech error") });
                }
              };

              const loop = async () => {
                while (this._active) {
                  await runOnce();
                  if (!this.continuous) break;
                }
                if (this._active) this.stop();
              };
              loop();
            }

            stop() {
              if (!this._active) return;
              this._active = false;
              try {
                window.hermes.invoke("capability.speechRecognition.stop", {});
              } catch (_) {}
              this._emit(this.onend, { type: "end" });
            }

            abort() {
              this.stop();
            }

            _emit(handler, event) {
              if (typeof handler === "function") {
                try { handler(event); } catch (_) {}
              }
            }

            _makeResultEvent(text) {
              const alt = { transcript: text, confidence: 1 };
              const res = { 0: alt, isFinal: true, length: 1 };
              return {
                type: "result",
                resultIndex: 0,
                results: { 0: res, length: 1 }
              };
            }
          }

          window.SpeechRecognition = HermesSpeechRecognition;
          window.webkitSpeechRecognition = HermesSpeechRecognition;
        })();
        """
        let speechShimScript = WKUserScript(source: speechShim, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContent.addUserScript(speechShimScript)

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
