# hermes-swift-ios

> The best way to use Hermes from your iPhone.

Native iOS client for [Hermes Agent](https://github.com/NousResearch/hermes-agent). The iPhone embeds the same WKWebView dashboard the [hermes-swift-mac](https://github.com/hermes-webui/hermes-swift-mac) app shows — pointed at your agent's URL, however you already reach it (Tailscale, public domain, local LAN) — with a JavaScript bridge that surfaces iPhone-native capabilities (camera, notifications, share sheet, biometrics) into the dashboard so the agent can use them.

## How you connect

**One QR. Two seconds.** This is the method.

- **On the Mac** — share the agent URL via the Mac app's QR (or paste the link).
- **On the iPhone** — first launch is a full-screen *Scan to connect* button. Tap → camera → QR. Done.

The QR carries the agent URL plus (optionally) a TLS cert fingerprint to pin against. The iPhone stores both in the Keychain and the WKWebView loads the dashboard. Same experience the Mac gives you, just on your phone.

Re-connect or add another agent? Same flow, surfaced as *Add another Hermes* in Settings.

## Reachability — not in this app

The iPhone reaches the agent URL however the user already does. We do not run a relay, a coordination server, or any infrastructure for this. **Set up reachability once at the agent layer** and every Hermes client — Mac, iPhone, future iPad, future Android — inherits it.

### Recommended options for users

| Setup | When it fits | Difficulty |
| --- | --- | --- |
| **Tailscale** (recommended for off-LAN) | You want the agent reachable from cellular too, with zero port-forwarding | 5 min — install on Mac + iPhone + iPad |
| LAN-only (`http://hermes.local:8787`) | Home use; phone and Mac on same WiFi | Trivial — works out of the box |
| Public domain + Let's Encrypt | You run a dedicated server with a real DNS name | 1 hour, needs DNS |
| Cloudflare Tunnel / ngrok / frp | Quick public exposure of a self-hosted agent without opening router ports | 10 min, needs a Cloudflare or ngrok account |

We don't bundle or require any of these — the app accepts whatever URL you enter. Tailscale is highlighted because it's the lowest-friction "works from anywhere" answer on Apple devices.

## What the JS bridge exposes

Inside the WKWebView, hermes-agent's web code can call:

```js
// Permission-gated
await window.hermes.invoke("capability.camera.scanQR")
await window.hermes.invoke("capability.biometrics.authenticate", { reason: "Confirm" })
await window.hermes.invoke("capability.notifications.schedule", { title: "Done", body: "Run finished" })

// No permission required
await window.hermes.invoke("capability.clipboard.write", { value: "hello" })
await window.hermes.invoke("capability.haptics.impact", { style: "medium" })
await window.hermes.invoke("capability.deviceInfo.get")
await window.hermes.invoke("capability.openURL.open", { url: "tel:+15555550100" })
await window.hermes.invoke("capability.appBadge.set", { count: 3 })
await window.hermes.invoke("capability.speech.speak", { text: "Hello" })
await window.hermes.invoke("capability.qrGenerator.generate", { payload: "..." })
await window.hermes.invoke("capability.documentPicker.pick", { allowMultiple: false })
await window.hermes.invoke("capability.share.present", { text: "share me" })
await window.hermes.invoke("meta.info") // { platform, appVersion }
```

### Capability surface at v0.1

| Capability | Permission | Methods |
| --- | --- | --- |
| `camera`         | `NSCameraUsageDescription` | `scanQR`, `takePhoto` (TODO) |
| `biometrics`     | `NSFaceIDUsageDescription` | `authenticate` |
| `notifications`  | runtime prompt | `schedule`, `cancel` |
| `share`          | none | `present` |
| `clipboard`      | none | `read`, `write`, `clear` |
| `haptics`        | none | `impact`, `notification`, `selection` |
| `deviceInfo`     | none | `get` |
| `openURL`        | none | `open`, `canOpen` |
| `appBadge`       | none | `set`, `clear` |
| `speech`         | none (TTS only) | `speak`, `stop`, `voices` |
| `qrGenerator`    | none | `generate` |
| `documentPicker` | none | `pick` |

**Held back until a clear user flow justifies them** — not in the binary, no plist keys declared: `location`, `contacts`, plus future `photos`, `calendar`, `reminders`, `microphone`, `speechRecognition`, `health`. Each costs App Store review scrutiny — and merely importing those frameworks can trigger Apple's privacy-manifest scanning — so we keep the binary clean until there's a real flow. Resurrect from git history when needed.

Adding a capability = a folder under `Sources/HermesCapabilities/` + a `register` line + (if permission-gated) a usage-description key in `project.yml` + (if it touches a required-reason API) an entry in `Sources/HermesApp/PrivacyInfo.xcprivacy`. See [CLAUDE.md](CLAUDE.md) and [docs/APP_STORE_SUBMISSION.md](docs/APP_STORE_SUBMISSION.md).

## Architecture at a glance

```
┌──────────────────── iPhone ────────────────────┐
│                                                │
│  ┌────────────┐    ┌─────────────────────────┐ │
│  │ HermesApp  │───▶│ HermesWebView (WKWebV.) │◀┐
│  │ (SwiftUI)  │    └────────┬────────────────┘ │
│  └────────────┘             │ JS bridge        │
│                             ▼                  │
│                    ┌────────────────────┐      │
│                    │ HermesCapabilities │      │
│                    │  Camera/Notif/...  │      │
│                    └────────────────────┘      │
└────────────────────┬───────────────────────────┘
                     │  reaches agent URL via
                     │  user's existing network
                     ▼
              hermes-agent dashboard
              (same target the Mac app uses)
```

## Repo structure

```
HermesiOS.xcodeproj/             # generated by XcodeGen
project.yml                      # XcodeGen spec — source of truth
Package.swift                    # SPM library targets
Sources/
  HermesApp/                     # @main, SwiftUI root + coordinator
  HermesWebView/                 # WKWebView wrapper + JS bridge + nav delegate
  HermesCapabilities/            # iPhone-native APIs surfaced to JS
    Camera/  Biometrics/  Notifications/  ShareSheet/
    Clipboard/  Haptics/  DeviceInfo/  OpenURL/
    AppBadge/  SpeechSynthesis/  QRGenerator/  DocumentPicker/
  HermesCore/                    # AppSettings, Keychain, Logger,
                                 # HermesEndpoint, EndpointStore,
                                 # EndpointQR, FingerprintPinner
  HermesUI/                      # ConnectHero, EndpointSetup, Settings
Tests/HermesiOSTests/
docs/QR_PAYLOAD.md               # wire format of the connect QR
```

## Build

Requires Xcode 15+, Swift 5.9+, iOS 16+ target.

```bash
brew install xcodegen           # one-time
xcodegen                        # materialize HermesiOS.xcodeproj
open HermesiOS.xcodeproj
```

For library code only: `swift build && swift test`.

## Security model

| Property | Mechanism |
| --- | --- |
| Confidentiality | HTTPS to hermes-agent; `http://` permitted for dev |
| Server identity | Optional SHA-256 leaf-cert pinning enforced by `FingerprintPinner` in `WKNavigationDelegate` |
| Endpoint storage | Keychain (`AfterFirstUnlockThisDeviceOnly`) — URL, fingerprint, optional bearer token all in one blob |
| Permissions | Each `HermesCapability` permission-gates its own API; only `NSCameraUsageDescription` and `NSFaceIDUsageDescription` declared at v0.1 |

## Status

Initial scaffold. Camera scanner, QR endpoint setup, Keychain-backed endpoint store, TLS pinning in the WKWebView's navigation delegate, JS bridge with capability routing — all wired. Mac-side QR generator is a separate small change on [hermes-swift-mac](https://github.com/hermes-webui/hermes-swift-mac).

## License

MIT — see [LICENSE](LICENSE).
