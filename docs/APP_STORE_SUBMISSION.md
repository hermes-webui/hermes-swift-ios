# App Store submission notes

Working notes for the human submitting hermes-swift-ios to App Store Connect. Keep up to date alongside major changes.

## Pre-flight checklist

- [ ] `xcodegen && xcodebuild -project HermesiOS.xcodeproj -scheme HermesiOS -destination 'generic/platform=iOS' archive` succeeds
- [ ] `PrivacyInfo.xcprivacy` is in the app bundle (Settings → Privacy Report on a built TestFlight build should show "No data collected")
- [ ] `ITSAppUsesNonExemptEncryption=false` is in Info.plist (set via `project.yml`) — no encryption-classification prompt on upload
- [ ] All declared `NS*UsageDescription` keys have a real corresponding user-facing flow (`NSCameraUsageDescription` → QR scanner; `NSFaceIDUsageDescription` → BiometricsCapability)
- [ ] No `UIBackgroundModes` declared
- [ ] No VPN / NetworkExtension entitlements
- [ ] CapabilityRegistry's auto-registered set matches the README's capability table (test: `CapabilityRegistryTests`)
- [ ] Bundle ID configured in your Apple Developer team (`com.hermeswebui.HermesiOS` or your override)

## App Privacy questionnaire answers

Fill in App Store Connect → App Privacy:

- **Data collected**: None. Endpoint URLs, fingerprints, and tokens are stored locally in the iOS Keychain; nothing is transmitted to us or to third parties.
- **Tracking**: No.
- **Required APIs**: declared in `PrivacyInfo.xcprivacy` — currently only `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` (the AppSettings onboarding flag).

If you later add capabilities that touch additional required-reason APIs (Photos library timestamps, system boot time, disk space, active keyboards), update `PrivacyInfo.xcprivacy` in the same PR.

## Reviewer notes (App Review Information → Notes field)

Copy this into the Notes field, edit demo URL/credentials:

```
Hermes is an iOS client for Hermes Agent (https://github.com/NousResearch/hermes-agent),
an open-source local-first agent runtime that ships its own browser-based dashboard.
This app embeds that dashboard in a WKWebView, pointed at a user-configured agent URL,
and adds a JavaScript bridge that gives the agent access to iPhone-native APIs
(camera, biometrics, notifications, share sheet, clipboard, haptics, document picker,
text-to-speech, QR generation).

The recommended user setup is Tailscale on both the Mac (hosting the agent) and the
iPhone, which gives the agent a stable, privately-routable hostname reachable from
anywhere. The app itself is reachability-agnostic and accepts any URL the user enters.

Native value over a web wrapper:
 - QR-based pairing with TLS leaf-cert fingerprint pinning (HermesCore.FingerprintPinner)
 - Keychain-backed endpoint storage with optional bearer-token injection
 - 12 native capabilities exposed to the dashboard JS via WKScriptMessageHandler
 - iOS-native onboarding, settings, and connection management (SwiftUI)

To test the app, please use the following demo credentials:
   Endpoint URL: <FILL IN — point at a public hermes-agent you spin up for review>
   OR: tap "Add another Hermes" → paste this QR string:
   hermes:agent:v1:<FILL IN — generate via EndpointQR.encode(...)>

NSAllowsArbitraryLoadsInWebContent is enabled because Hermes Agent is commonly
self-hosted on a user's own machine, LAN, or Tailscale tailnet where TLS may not
be configured. The user explicitly enters/scans their agent URL and is shown
its TLS state (lock-shield icon when pinned) in Settings. Native networking is
not exempted from ATS.

The custom URL scheme hermes:// is used for endpoint share fallback
(hermes://agent?payload=...) — same payload as the QR, just delivered as a
deep link.
```

## Setting up a demo agent for review

Apple's reviewers cannot reach a Mac on your home network. They need a publicly accessible hermes-agent endpoint to exercise the app. Options:

1. **Spin up a temporary public hermes-agent** on a small VPS, generate the connect QR with `EndpointQR.encode(...)`, paste the resulting `hermes:agent:v1:...` string into the reviewer notes. Decommission after the build is approved.
2. **Use a tunnel** — `cloudflared tunnel` or `ngrok` exposing your local hermes-agent for the duration of review. Free, fast to set up, but leaves your agent publicly accessible while the tunnel is up.
3. **Provide reviewer-only credentials** to a long-running shared demo instance you operate.

Without one of these, the most likely outcome is a Guideline 4.2 / 2.1 rejection citing "we couldn't test your app's core functionality."

## What to expect

- **First submission**: 1–3 day review window typical. Expect questions about the WKWebView wrapper (Guideline 4.2) and `NSAllowsArbitraryLoadsInWebContent`. The reviewer notes above answer both.
- **Subsequent updates**: usually 24h or less once your bundle ID has a clean review history.
- **Common rejection reasons we've designed against**:
  - "Just a website wrapper" → the 12 native capabilities + native onboarding answer this.
  - "Requests permissions you don't use" → only `NSCameraUsageDescription` + `NSFaceIDUsageDescription` declared, both with real flows.
  - "VPN/background-mode entitlement without justification" → we don't request either.

## Future capability additions and review impact

| Adding | Review impact |
| --- | --- |
| Location | Moderate — needs `NSLocationWhenInUseUsageDescription` + visible flow. Usually fine. |
| Photos | Moderate — needs `NSPhotoLibraryUsageDescription`. |
| Calendar / Reminders | Moderate — needs `NSCalendarsUsageDescription` / `NSRemindersUsageDescription`. |
| Microphone + SpeechRecognition | High — extra scrutiny on always-on listening. |
| Contacts | High — frequently rejected without an obvious user flow. |
| HealthKit | Highest — separate review track, days longer. |
| VPN / NetworkExtension | Highest — App Review will challenge unless core to the product. |
| Background modes (audio/voip) | High — routinely rejected when not core. |
| In-app purchase | Separate review track + Apple's 15–30% revenue cut. |
