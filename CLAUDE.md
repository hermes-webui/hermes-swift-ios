# CLAUDE.md — hermes-swift-ios

> Read this before touching any code. Native iOS app wrapping hermes-webui via WKWebView, with a bridge to control a paired Mac instance and iPhone-native capability surface.

---

## What this project is

A native iOS app that loads hermes-webui in a `WKWebView` and adds two things the web UI can't do alone:

1. **Bridge to a paired Mac** running `hermes-swift-mac` — discovered via Bonjour on the same LAN, with a cloud relay fallback for off-network. Lets the iPhone control the Mac instance (run commands, observe state, push events).
2. **iPhone-native capabilities** — camera, location, contacts, notifications, share sheet, biometrics — surfaced both to native SwiftUI screens and to hermes-webui via a `WKScriptMessageHandler` JS bridge (`window.webkit.messageHandlers.hermes`).

**Language:** Swift 5.9+
**Min target:** iOS 16
**Project gen:** [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `project.yml` is the source of truth, `HermesiOS.xcodeproj` is regenerated, never hand-edited
**Tests:** `swift test` (library) + Xcode test action for UI tests
**Sister repo:** [hermes-swift-mac](https://github.com/hermes-webui/hermes-swift-mac) — read its CLAUDE.md too; many WebKit/ATS gotchas carry over.

---

## Repo structure

```
project.yml                   # XcodeGen spec — edit this, not the .xcodeproj
Package.swift                 # SPM library targets — Sources/* live here
Sources/
  HermesApp/                  # @main, SwiftUI App + root coordinator
  HermesWebView/              # WKWebView wrapper + JS bridge router
  HermesBridge/               # iOS ⇄ Mac control plane
    Transport/                # Bonjour + WebSocket (LAN), Relay (cloud)
    Protocol/                 # Codable Message envelope + typed Commands
    Pairing/                  # QR pairing + Keychain-backed PairedDevice
  HermesCapabilities/         # iPhone-native APIs — one folder per capability
  HermesCore/                 # Config, Keychain, logging — cross-cutting
  HermesUI/                   # Native SwiftUI screens (settings, pairing, status)
Tests/HermesiOSTests/
docs/BRIDGE_PROTOCOL.md       # JSON-over-WebSocket message contract
```

---

## The rules

### Never push directly to main
All changes through a named branch + PR. Tests must pass. (Exception: the very first seed commit on an empty repo.)

### `project.yml` is the source of truth
Never hand-edit `HermesiOS.xcodeproj`. Modify `project.yml`, then `xcodegen` to regenerate. The `.xcodeproj` is `.gitignore`d.

### Info.plist key parity
Any Info.plist key the app needs at runtime must be declared in `project.yml` under `targets.HermesiOS.info.properties` (XcodeGen generates the plist). Don't drop loose `Info.plist` files in random places.

### Bridge protocol is versioned
Every message includes a `protocolVersion`. Bump it in [docs/BRIDGE_PROTOCOL.md](docs/BRIDGE_PROTOCOL.md) and in `Protocol/Message.swift` *together* when changing the wire format. The Mac-side BridgeServer must accept the same version range.

### Capabilities are permission-gated
Every `HermesCapabilities/*` module must:
- Check permission status before doing work
- Surface a user-visible prompt if not granted
- Add the matching `NS*UsageDescription` key to `project.yml` (e.g. `NSCameraUsageDescription`)

If you add a capability and forget the usage description, the app **crashes on launch** the first time the API is touched. No silent failures.

---

## WKWebView rules — read before touching `Sources/HermesWebView/`

### ATS (App Transport Security)
`http://localhost` is ATS-exempt automatically. Any other `http://` URL — Bonjour-resolved Mac IPs, LAN IPs, hostnames — is **blocked by default**.

For development against a non-HTTPS hermes-webui server on the LAN, add to `project.yml`:

```yaml
NSAppTransportSecurity:
  NSAllowsArbitraryLoadsInWebContent: true   # web content only, not native networking
```

Native networking (the bridge's WebSocket transport) is **not** affected by `NSAllowsArbitraryLoadsInWebContent`. WebSocket connections to plain `ws://` need `NSExceptionDomains` entries for the specific hostnames, or `wss://` everywhere.

### Navigation delegate — implement both failure callbacks
```swift
func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error)
func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error)
```

Same gotcha as the Mac app (see hermes-swift-mac CLAUDE.md): missing either one causes silent failures. Filter `NSURLErrorCancelled` (-999), surface helpful messages for -1022 (ATS), -1004 (connection refused), -1003 (DNS).

### JS bridge contract
The web UI calls into native via:

```js
window.webkit.messageHandlers.hermes.postMessage({
  id: "msg-uuid",
  method: "capability.camera.takePhoto",  // or "bridge.command.run", etc.
  params: { ... }
});
```

Responses are delivered back into the page by injecting:

```js
window.hermes.deliverResponse({ id, result, error })
```

`JSBridge.swift` is the single router — all `message.name === "hermes"` traffic goes through it. Don't register additional `WKScriptMessageHandler` names.

---

## Bridge rules — read before touching `Sources/HermesBridge/`

- **Always Codable** — never `[String: Any]` for wire types. See `Protocol/Message.swift`.
- **Protocol versioning** — `Message.protocolVersion` must match `BridgeProtocol.currentVersion`. Reject mismatches with a typed error.
- **Transport-agnostic Client** — `BridgeClient` doesn't know if it's on Bonjour, WebSocket, or Relay. It holds a `Transport` and delegates send/receive. Add new transports by conforming to the `Transport` protocol, not by branching inside the client.
- **Pairing is one-time** — Mac shows a QR with `{host, port, token, fingerprint}`; iOS scans, validates fingerprint, stores token in Keychain via `HermesCore.Keychain`. Re-pair only on user request or fingerprint mismatch.
- **Tokens never go in UserDefaults or plist** — Keychain only.

---

## Capability rules — read before adding a `HermesCapabilities/*` module

Every capability has:

1. A folder under `Sources/HermesCapabilities/<Name>/`
2. A type conforming to `Capability` (`name`, `permissionStatus`, `requestPermission`, `invoke(method:params:)`)
3. A matching `NS*UsageDescription` entry in `project.yml`
4. Registration in `CapabilityRegistry` (lazy — registration doesn't trigger permission prompts)
5. A test in `Tests/HermesiOSTests/Capabilities/`

The registry's job is to be the single place the JS bridge looks up capability handlers. If you add a capability without registering it, the JS bridge will reject calls with `error.code = "unknown_capability"`.

---

## App Store review notes — read before adding entitlements, plist keys, or capabilities

App Review will reject submissions for several specific patterns. We trim the surface area to only what's actually used so reviews stay fast.

**Permission strings:** Only declare an `NS*UsageDescription` in `project.yml` in the **same PR** that wires up the user-facing flow which triggers it. Declaring keys you don't use is flagged as "requesting permissions you don't use." Currently declared: `NSCameraUsageDescription` (QR pairing scanner), `NSFaceIDUsageDescription` (BiometricsCapability), `NSLocalNetworkUsageDescription` (Bonjour). Deferred: microphone, photo library, location, contacts.

**High-scrutiny permissions** — get a second look before adding:

- **Contacts (`NSContactsUsageDescription`)** — frequently rejected when the user flow doesn't make access obviously necessary. `ContactsCapability` exists in the codebase but is **not registered by default**; opt it in only with a concrete UI flow.
- **Microphone, Photo Library, Location-Always, Health, Bluetooth (always-on)** — same caution.

**Background modes:** No `UIBackgroundModes` are declared in the first submission. `voip` and `audio` get rejected when they're not core to the app's purpose. Add background modes — with reviewer-facing justification — only alongside the feature that needs them.

**ATS (App Transport Security):** `NSAllowsArbitraryLoadsInWebContent` is set so the WKWebView can load non-HTTPS hermes-webui instances on a LAN. This is reviewable but generally accepted for browser-style apps; native networking is not exempted. Switch to HTTPS-everywhere before shipping when feasible.

**Encryption (`ITSAppUsesNonExemptEncryption`):** WebSocket over TLS counts as standard encryption — declare `ITSAppUsesNonExemptEncryption=false` once we ship to TestFlight unless we add custom crypto.

**Web content policy:** WKWebViews that load user-controlled URLs need to be presented as a clear browser/agent surface, not a wrapped third-party site. The settings screen exposing the target URL helps here.

When in doubt, slim down. Removing a permission later costs nothing; getting rejected and re-submitting costs days.

## Common gotchas

- **iOS Simulator and Bonjour** — works on real device + Mac on same WiFi; Simulator Bonjour is flaky. Test pairing on hardware.
- **WKWebView and cookies** — WKWebsiteDataStore isolates cookies per app; if hermes-webui auth expects a shared session with the Mac, plan for token-based auth via the bridge instead.
- **Background WebSocket** — iOS pauses URLSession WebSocket tasks in background. The bridge has to reconnect on `UIApplication.didBecomeActiveNotification`. See `SessionManager.swift`.
- **Universal Links / Deep Links** — `hermes://` custom URL scheme is reserved for pairing QR fallback (`hermes://pair?host=...&token=...`). Register in `project.yml`.

---

## Opus mentor

When uncertain about Swift APIs, WKWebView quirks, ATS configuration, or iOS lifecycle — ask before guessing:

```bash
{ cat Sources/HermesBridge/BridgeClient.swift; cat docs/BRIDGE_PROTOCOL.md; } \
  | claude --model claude-opus-4-7 --thinking enabled \
  --print 'Senior iOS engineer. [DESCRIBE SITUATION].
Review for: WKWebView config, JS bridge security, transport correctness, background behavior.
Provide exact Swift code.'
```
