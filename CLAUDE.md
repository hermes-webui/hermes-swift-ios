# CLAUDE.md — webui iOS app

> Read this before touching any code. Native iOS app embedding a webui dashboard in a `WKWebView`, with a JS bridge for iPhone-native capabilities.

---

## What this project is

A SwiftUI iOS app that loads a user-configured webui URL in a `WKWebView` — the same dashboard the desktop app loads — and adds two things the web UI can't do alone:

1. **iPhone-native capabilities surfaced into the web UI** — `WKScriptMessageHandler` JS bridge (`window.hermes.invoke(...)`). Camera, share sheet, notifications today; more as the app grows.
2. **A native-feeling onboarding + endpoint setup** — first launch is a scan-to-connect screen, paired endpoints persist in the Keychain, optional TLS leaf-cert pinning via QR-carried fingerprint.

**This app does NOT** run a machine-specific bridge protocol, operate any relay or coordination server, or solve cross-network reachability. The iPhone reaches the webui URL via whatever path the user already has set up — the documented and recommended path is **Tailscale on both devices**, but the app accepts any URL (LAN, public domain, Cloudflare Tunnel, ngrok).

**Language:** Swift 5.9+
**Min target:** iOS 16
**Project gen:** [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `project.yml` is the source of truth, `Hermes_IOS.xcodeproj` is regenerated, never hand-edited
**Tests:** `swift test` (library targets) + Xcode test action
Sister repo guidance removed for agnostic setup.

---

## Repo structure

```
project.yml                   # XcodeGen spec — edit this, not the .xcodeproj
Package.swift                 # SPM library targets
Hermes_IOS/
  Hermes_IOSApp.swift         # @main, SwiftUI App + root coordinator
  HermesWebView/              # WKWebView wrapper + JS bridge router + nav delegate
  HermesCapabilities/         # iPhone-native APIs — one folder per capability
  HermesCore/                 # AppSettings, Keychain, Logger, HermesEndpoint,
                              # EndpointStore, EndpointQR, FingerprintPinner
  HermesUI/                   # Connection + settings UI
Tests/HermesiOSTests/
docs/QR_PAYLOAD.md            # connect-QR wire format
```

---

## The rules

### Never push directly to main
All changes through a named branch + PR. Tests must pass. (Exception: the very first seed commit on an empty repo.)

### `project.yml` is the source of truth
Never hand-edit `Hermes_IOS.xcodeproj`. Modify `project.yml`, then `xcodegen` to regenerate. The `.xcodeproj` is `.gitignore`d.

### Info.plist key parity
Any Info.plist key the app needs at runtime must be declared in `project.yml` under `targets.HermesiOS.info.properties` (XcodeGen generates the plist).

### Endpoint protocol versioning
QR payload protocol version is carried in the wire prefix (`hermes:agent:v1:`). If you change protocol shape, bump prefix and docs together.

### Capabilities are permission-gated
Every `HermesCapabilities/*` module must:
- Check permission status before doing work
- Surface a user-visible prompt if not granted
- Add the matching `NS*UsageDescription` key to `project.yml` (e.g. `NSCameraUsageDescription`)

If you add a capability and forget the usage description, the app **crashes on launch** the first time the API is touched. No silent failures.

---

## WKWebView rules — read before touching `Hermes_IOS/HermesWebView/`

### ATS (App Transport Security)
`http://localhost` is ATS-exempt automatically. Any other `http://` URL — Tailscale magic-DNS, LAN IPs — is **blocked by default**.

`NSAllowsArbitraryLoadsInWebContent` is set in `project.yml` so the WebView can load non-HTTPS webui deployments during development. Native networking is **not** affected by this; if you ever do native HTTPS calls, they hit the standard trust store unless you pin.

### Navigation delegate — implement both failure callbacks
```swift
func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error)
func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error)
```

Missing either causes silent failures. Filter `NSURLErrorCancelled` (-999), surface helpful messages for -1022 (ATS), -1004 (refused), -1003 (DNS), -1202 (TLS pinning failure).

### TLS pinning
When the active `HermesEndpoint` has a `leafCertFingerprint`, `NavigationDelegate.webView(_:didReceive:completionHandler:)` enforces it during the TLS handshake. Mismatch → `cancelAuthenticationChallenge`. This is the *only* place pinning happens for the WebView; don't add a parallel `URLSessionDelegate` that disagrees.

### JS bridge contract
The web UI calls into native via:

```js
window.webkit.messageHandlers.hermes.postMessage({
  id: "msg-uuid",
  method: "capability.camera.scanQR",  // or "meta.info"
  params: { ... }
});
```

Responses are delivered back into the page by injecting:

```js
window.hermes.deliverResponse({ id, result, error })
```

`JSBridge.swift` is the single router — all `message.name === "hermes"` traffic goes through it. Don't register additional `WKScriptMessageHandler` names.

---

## Capability rules — read before adding a `HermesCapabilities/*` module

Every capability has:

1. A folder under `Hermes_IOS/HermesCapabilities/<Name>/`
2. A type conforming to `Capability` (`name`, `permissionStatus`, `requestPermission`, `invoke(method:params:)`)
3. (Permission-gated only) A matching `NS*UsageDescription` entry in `project.yml`
4. Registration in `CapabilityRegistry.registerDefaults()` — lazy, no permission prompts on registration
5. A test in `Tests/HermesiOSTests/Capabilities/`

The registry's job is to be the single place the JS bridge looks up capability handlers. If you add a capability without registering it, the JS bridge will reject calls with `unknown capability`.

### Auto-registered at v0.1

Permission-gated: `camera` (`NSCameraUsageDescription`), `notifications` (runtime prompt).
No-permission utilities: `share`, `clipboard`, `haptics`, `deviceInfo`, `openURL`, `appBadge`, `speech` (TTS), `qrGenerator`, `documentPicker`.

### Deliberately NOT in the binary

`LocationCapability` and `ContactsCapability` were removed entirely (not just deregistered). Reason: Apple's privacy-manifest scanning flags apps that import `CoreLocation` / `Contacts` without matching usage descriptions. Keeping unused code that touches those frameworks pays App Store review tax for no benefit. Resurrect from git history when a concrete user-facing flow needs them, in the same PR that adds the matching `NS*UsageDescription` to `project.yml` AND adds the matching entry to `PrivacyInfo.xcprivacy`.

Same applies to future `photos`, `calendar`, `reminders`, `microphone`, `speechRecognition`, `health` — never check in the framework-using code until the flow that exercises it ships in the same PR.

---

## App Store review notes — read before adding entitlements, plist keys, or capabilities

We trim the surface area to only what's actually used so reviews stay fast.

**Permission strings:** Only declare an `NS*UsageDescription` in `project.yml` in the **same PR** that wires up the user-facing flow which triggers it. Apple flags "requesting permissions you don't use." Currently declared: `NSCameraUsageDescription` (QR connect scanner).

**High-scrutiny permissions** — get a second look before adding:

- **Contacts (`NSContactsUsageDescription`)** — frequently rejected when the user flow doesn't make access obviously necessary. Code stays available but not auto-registered until there's a concrete UI flow.
- **Microphone, Photo Library, Location-Always, Health, Bluetooth (always-on)** — same caution.

**Background modes:** None declared at v0.1. `voip` and `audio` get rejected when they're not core to the app's purpose. Add background modes — with reviewer-facing justification — only alongside the feature that needs them.

**ATS:** `NSAllowsArbitraryLoadsInWebContent` is set so the WKWebView can load non-HTTPS webui URLs (LAN dev / Tailscale magic-DNS). Reviewable but generally accepted for browser-style apps. Native networking is not exempted.

**Encryption (`ITSAppUsesNonExemptEncryption`):** declare `false` once we ship to TestFlight unless we add custom crypto.

When in doubt, slim down. Removing a permission later costs nothing; getting rejected and re-submitting costs days.

---

## Common gotchas

- **Universal Links / Deep Links** — `hermes://agent?payload=<base64>` is reserved for endpoint-share fallback. Registered in `project.yml` under `CFBundleURLTypes`.
- **WKWebView and cookies** — `WKWebsiteDataStore` is isolated per app. If the webui expects a shared session, plan for a real auth flow at the webui layer instead of relying on shared cookies.
- **Camera in Simulator** — no real camera, but the QR scanner's permission gate still works. Test end-to-end on hardware.
