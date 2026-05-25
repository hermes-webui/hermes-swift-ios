# hermes-swift-ios

> Native iPhone client for Hermes WebUI.

Native iOS client for Hermes WebUI. The app loads your configured WebUI URL (Tailscale, public domain, local LAN, tunnel) in WKWebView and exposes iPhone-native capabilities (camera, notifications, share sheet, biometrics, etc.) through a JavaScript bridge.

## How you connect

**Install [Tailscale](https://tailscale.com) on your WebUI machine and iPhone. Scan one QR. Done.**

That's the recommended path. Tailscale gives your WebUI machine a stable hostname (for example `hermes.tailnet.ts.net`) reachable from cellular, hotel WiFi, anywhere — no port forwarding, no public DNS, no router config. Hermes WebUI can expose a QR payload with that hostname; the iPhone scans it; WKWebView opens the dashboard.

- **On the WebUI machine** — run Hermes WebUI and share the WebUI URL via QR (or copy/paste URL manually).
- **On the iPhone** — open Connections and scan QR, or enter host + WebUI password manually.

The QR carries the WebUI URL plus (optionally) a TLS cert fingerprint to pin against. The iPhone stores both in the Keychain and WKWebView loads the dashboard.

Re-connect or add another endpoint? Same flow in *Connections*.

> You don't *have* to use Tailscale — the app accepts any URL. See [Reachability](#reachability--not-in-this-app) below for the full set of options if you have a different setup.

## Reachability — not in this app

The iPhone reaches the WebUI URL however the user already does. We do not run a relay, a coordination server, or any infrastructure for this. **Set up reachability once at the WebUI layer** and every Hermes client inherits it.

### Tailscale — the recommended setup

This is the path we recommend, and it's the assumption the rest of the docs are written against. It's the only setup that gives you:

- ✅ Works from cellular, hotel WiFi, anywhere
- ✅ Zero port forwarding, zero public DNS
- ✅ Free for personal use
- ✅ Stable hostname (`hermes.<your-tailnet>.ts.net`) the QR can carry
- ✅ End-to-end encrypted WireGuard tunnel underneath

Steps:
1. Install Tailscale on your WebUI machine and iPhone (sign in with the same account on both)
2. Note the machine tailnet hostname from Tailscale — something like `studio.tailnet.ts.net`
3. Run Hermes WebUI on that machine
4. Generate/share the iPhone connect QR (or copy host + password)
5. Scan from the iPhone — done

### Other options that work

The app accepts any URL, so you can skip Tailscale if you already have one of these set up:

| Setup | When it fits | Difficulty |
| --- | --- | --- |
| **Tailscale** | Default; reach WebUI from anywhere | 5 min, both devices |
| LAN-only (`http://hermes.local:8787`) | Home use; phone and WebUI machine on same WiFi | Trivial — works out of the box |
| Public domain + Let's Encrypt | You run WebUI on a dedicated server with DNS | 1 hour, needs DNS |
| Cloudflare Tunnel / ngrok / frp | Quick public exposure of self-hosted WebUI without opening router ports | 10 min, needs account setup |

We don't bundle or require any of these — Tailscale is highlighted because it's the lowest-friction "works from anywhere" answer on Apple devices, and the path with the smallest blast radius (no machine becomes publicly addressable, no router config).

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
                     │  reaches WebUI URL via
                     │  user's existing network
                     ▼
              Hermes WebUI dashboard
```

## Repo structure

```
Hermes_IOS.xcodeproj/
Hermes_IOS/
  Hermes_IOSApp.swift            # @main
  Info.plist
  HermesApp/                     # privacy manifest
  HermesWebView/                 # WKWebView wrapper + JS bridge + nav delegate
  HermesCapabilities/            # iPhone-native APIs surfaced to JS
    Camera/  Biometrics/  Notifications/  ShareSheet/
    Clipboard/  Haptics/  DeviceInfo/  OpenURL/
    AppBadge/  SpeechSynthesis/  QRGenerator/  DocumentPicker/
  HermesCore/                    # AppSettings, Keychain, Logger,
                                 # HermesEndpoint, EndpointStore,
                                 # EndpointQR, FingerprintPinner
  HermesUI/                      # ConnectHero, Settings, RootView, EndpointEditor
Hermes_IOSTests/
Hermes_IOSUITests/
docs/QR_PAYLOAD.md               # wire format of the connect QR
```

## Build

Requires Xcode 15+ and iOS 16+ target.

```bash
open Hermes_IOS.xcodeproj
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

Active iOS client for Hermes WebUI. Includes QR/manual connection flow, Keychain-backed endpoint store, TLS pinning support, and JS capability bridge.

## License

MIT — see [LICENSE](LICENSE).
