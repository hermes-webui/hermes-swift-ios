# hermes-swift-ios

Native iPhone client for connecting to a webui over Tailscale.

## Connection Flow (Tailscale)

1. Install Tailscale on the machine running your webui and on iPhone.
2. Sign in to the same tailnet on both.
3. Run webui on the machine (default port `8787`).
4. In the iPhone app, open **Connections**.
5. Connect by either:
   - scanning a connection QR code, or
   - entering `tailscale-ip[:port]` or `tailnet-hostname[:port]`.
6. If no port is provided, the app uses `8787`.

## Permissions Used

- `NSCameraUsageDescription` (QR scanning)
- `NSMicrophoneUsageDescription` (voice input when activated from webui)
- `NSSpeechRecognitionUsageDescription` (speech-to-text when activated from webui)
- Notifications permission (requested when In-app notifications is turned on)

## Capability Surface

- Camera / QR
- Notifications
- Share sheet
- Clipboard
- Haptics
- Device info
- Open URL
- App badge
- Speech synthesis
- Speech recognition
- QR generation
- Document picker

## Build

Requires Xcode 15+ and iOS 16+ target.

```bash
open Hermes_IOS.xcodeproj
```

## License

MIT — see [LICENSE](LICENSE).
