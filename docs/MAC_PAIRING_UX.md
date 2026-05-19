# Mac-side pairing UX requirements

Lives in this repo because the iOS app's first-launch experience is built around the assumption that the Mac side honours these constraints. When the `BridgeServer` PR lands in [hermes-swift-mac](https://github.com/hermes-webui/hermes-swift-mac), it must match this spec.

## Principle

**Pairing is a hero action, not a setting.** The user's mental model is: "pull out my phone, point it at my Mac, done." If the answer to "how do I pair my iPhone?" is "open Preferences and find the right tab," we've failed.

Target latency, measured from the Mac being awake and unlocked to the QR being on screen:
- **≤ 2 seconds** via the recommended path
- **≤ 5 seconds** via any path a first-time user might reasonably take

## Required surfaces (all three)

Implementing only one is not enough — different users have different habits.

### 1. Menubar item — primary path

The Hermes menubar item (already exists in [`AppDelegate.setupMenu`](https://github.com/hermes-webui/hermes-swift-mac/blob/main/Sources/HermesAgent/AppDelegate.swift)) must include a top-level **"Pair iPhone…"** item at the **very top** of the menu, above "Show Window." Clicking opens the pairing window directly — no submenu, no Preferences detour.

The pairing window is a dedicated `NSWindow` (not a tab in Preferences) showing:
- A large QR (target ≥ 320×320 pt so it scans cleanly from arm's length)
- The pairing payload as selectable text underneath (for AirDrop / manual paste fallback)
- A "Cancel" / close button

When the iPhone successfully connects, the window auto-dismisses with a brief success animation.

### 2. Global hotkey — power-user path

Bind **⇧⌘P** (Shift-Command-P) to the pairing action — same handler as the menubar item. Hotkey is configurable in Preferences but the default must be bound out of the box. Use the existing `HotkeyRecorderView` infrastructure.

### 3. Toolbar button in the browser window — discoverability path

Add a small QR-code icon button in the `BrowserWindowController` window's right-side toolbar, between the URL field and the SSH status indicator. Tooltip: "Pair iPhone (⇧⌘P)". Single click → pairing window.

## What pairing must NOT require

- **Opening Preferences first.** Acceptable as a *secondary* path (a "Pair iPhone…" button on a "Devices" tab if you want), but never the only path.
- **Quitting and re-launching.** First launch should not gate pairing.
- **Configuring sshd, opening firewall ports manually, or any system-level permission outside the LAN permission prompt iOS shows.**

## QR payload — same format as iOS expects

```
hermes:pair:v1:<base64url-encoded JSON of PairingPayload>
```

`PairingPayload` fields (see [`Sources/HermesBridge/Pairing/QRPairing.swift`](../Sources/HermesBridge/Pairing/QRPairing.swift)):

| Field | Source |
| --- | --- |
| `version` | always `1` for protocol v1 |
| `deviceId` | stable Mac identifier (Hardware UUID or app-generated, persisted) |
| `displayName` | the Mac's `ComputerName` or user-set name |
| `host` | LAN-reachable hostname or IP (prefer `.local` mDNS name) |
| `port` | port the WebSocket listener is bound to |
| `fingerprint` | lowercase hex SHA-256 of the leaf cert's DER bytes — compute via [`FingerprintPinner.fingerprint(ofDER:)`](../Sources/HermesBridge/Transport/FingerprintPinner.swift) |
| `deviceToken` | single-use random bearer token; the server rotates this via `authRotated` on first successful handshake |
| `relayRoutingToken` | optional; only present when the user has opted into the cloud relay |

## Token lifecycle (Mac side)

1. User triggers pairing → server mints a fresh per-iPhone `deviceToken`, persists it as "pending."
2. QR displays with this token baked in.
3. iPhone scans, opens `wss://`, authenticates with the pending token.
4. **First successful handshake** → server promotes the token to "active," then immediately sends `authRotated` with a brand-new replacement token. Server now accepts only the rotated token (with an optional 60 s grace window for the old one).
5. Subsequent connections use the rotated token. The QR token is permanently invalidated.

This means a QR photographed in transit is useless to an attacker after the legitimate device's first connect.

## See also

- [BRIDGE_PROTOCOL.md](BRIDGE_PROTOCOL.md) — full wire format including `authRotated`
- [iOS `PairHeroView.swift`](../Sources/HermesUI/PairHeroView.swift) — what the user sees on iOS at first launch
