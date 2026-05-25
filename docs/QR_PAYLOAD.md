# Connect-QR payload — v1

The QR code Hermes-on-Mac shows when sharing a connection with the iPhone.

## Wire format

```
hermes:agent:v1:<base64url(JSON)>
```

Also accepted as a deep link:

```
hermes://agent?payload=<base64url(JSON)>
```

Both decode to the same JSON.

## JSON shape

```json
{
  "version": 1,
  "url": "https://hermes.tailnet.ts.net",
  "displayName": "Home",
  "leafCertFingerprint": "a1b2…ef",
  "bearerToken": "optional-static-token"
}
```

| Field | Required | Notes |
| --- | --- | --- |
| `version` | yes | Always `1` for this protocol revision. Bump in code + this doc together. |
| `url` | yes | The webui URL the iPhone's WKWebView will load. `http://` or `https://`. |
| `displayName` | yes | User-facing label shown in Settings. |
| `leafCertFingerprint` | no | Lowercase-hex SHA-256 of the agent's TLS leaf certificate (DER bytes). Enables pinning. Omit for plain HTTP. |
| `bearerToken` | no | Static `Authorization: Bearer …` header sent on each main-frame request. Stored in the Keychain. |

## Computing the fingerprint (Mac side)

The same function the iPhone uses for verification is exposed publicly so the Mac and any unit tests stay in lockstep:

```swift
FingerprintPinner.fingerprint(ofDER: certDERData)
// -> "a1b2c3...ef" (64 lowercase hex chars)
```

## Security model

- **Confidentiality**: provided by HTTPS to the agent. `http://` is permitted for dev only.
- **Server identity**: when `leafCertFingerprint` is present, the iPhone's `WKNavigationDelegate` enforces pinning during the TLS handshake. Mismatch = connection refused. Rotating the agent's keypair requires re-sharing the QR.
- **Client auth**: optional `bearerToken` on each request. Use rotating tokens at the agent layer; this protocol carries the current value opaquely.
- **No mutual TLS at v1**; can be added in a future payload version.

## Reachability — not this protocol's job

The iPhone reaches `url` using whatever network path the user already has set up. **The recommended setup is Tailscale** on both the Mac and the iPhone — it gives the Mac a stable hostname (e.g. `hermes.tailnet.ts.net`) reachable from cellular and any WiFi without port forwarding or public DNS. The QR's `url` field is just the tailnet hostname.

Other setups (public domain + Let's Encrypt, LAN-only, Cloudflare Tunnel, ngrok) work identically — the QR carries whatever URL is right for the user's setup. This app does not operate any reachability infrastructure of its own; if webui is on a private network the iPhone can't reach, the connection fails the same way Safari would.
