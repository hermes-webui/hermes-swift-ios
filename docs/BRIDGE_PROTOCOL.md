# Bridge Protocol — v1

Wire contract between **hermes-swift-ios** (BridgeClient) and the future **hermes-swift-mac BridgeServer**. JSON over **`wss://`** (TLS-wrapped WebSocket) on the LAN, JSON over `wss://` through a relay off-LAN. The envelope and message types are identical across transports.

## Security model

Three layers, no SSH:

1. **TLS in transit (`wss://`)** — the Mac BridgeServer terminates TLS with a self-signed certificate generated at install time. Plain `ws://` is accepted by the iPhone client only as a development convenience and emits a warning log; production builds should refuse it.
2. **Server identity pinning** — the QR pairing payload carries `fingerprint`, the lowercase-hex SHA-256 of the Mac's leaf cert (DER bytes). The iPhone enforces this in `FingerprintPinner` during the TLS handshake; mismatches abort the connection. Rotating the Mac's keypair therefore *requires* a re-pair.
3. **Bearer-token auth + rotation** — the QR carries a `deviceToken` baked in by the Mac for this iPhone. The iPhone sends it as `Authorization: Bearer <deviceToken>` on every WebSocket upgrade. On first successful handshake after pairing, the Mac sends an `authRotated` message replacing the QR-baked token with a fresh, never-transmitted-in-the-clear-QR one. A QR photographed in transit becomes useless after the legitimate device's first connect.

> **Versioning rule:** bump `BridgeProtocol.currentVersion` in code and the version header in this doc *in the same commit*. The server MUST reject messages whose `protocolVersion` is outside its `supportedVersions` range with a `error` payload using code `unsupported_version`.

---

## Connection

### LAN (Bonjour + WebSocket)

The Mac BridgeServer advertises `_hermes._tcp` via Bonjour on the local network with a TXT record:

```
deviceId=<stable-uuid>
displayName=<user-visible-name>
version=1
fingerprint=<base64-of-server-keypair-hash>
```

The iPhone discovers via `NWBrowser`, then opens a TLS WebSocket:

```
GET wss://<host>:<port>/v1/bridge
Authorization: Bearer <deviceToken>
X-Hermes-Protocol-Version: 1
```

`deviceToken` is the per-iPhone token issued during pairing. The server validates the token, accepts the upgrade, and the bidirectional channel is open. The iPhone's `FingerprintPinner` rejects the handshake if the server's leaf-cert SHA-256 doesn't match the `fingerprint` field captured in the QR.

### Relay (cloud fallback)

Same wire format, different endpoint:

```
GET wss://<relayHost>/v1/bridge/<routingToken>
Authorization: Bearer <deviceToken>
X-Hermes-Protocol-Version: 1
```

Both Mac and iPhone connect with the same `routingToken` (issued during pairing). The relay is a stateless multiplexer — it copies frames between the two ends and does not interpret them.

---

## Envelope

Every frame is a JSON object:

```json
{
  "id": "uuid-of-this-message",
  "protocolVersion": 1,
  "kind": "commandRequest | commandResponse | event | capabilityRequest | capabilityResponse | ping | pong | error",
  "payload": { "type": "<kind>", "data": { ... } }
}
```

For `ping` and `pong`, `payload.data` is omitted.

---

## Message kinds

### `commandRequest` — iPhone → Mac

The iPhone asks the Mac to do something.

```json
{
  "id": "msg-1",
  "protocolVersion": 1,
  "kind": "commandRequest",
  "payload": {
    "type": "commandRequest",
    "data": {
      "command": "agent.runPrompt",
      "params": { "prompt": "summarize my email", "conversationId": "c-42" }
    }
  }
}
```

**Well-known commands:**

| Command | Direction | Params | Result |
| --- | --- | --- | --- |
| `agent.runPrompt` | iOS→Mac | `{ prompt: string, conversationId?: string }` | `{ runId: string }` |
| `agent.cancelRun` | iOS→Mac | `{ runId: string }` | `null` |
| `agent.getState` | iOS→Mac | `null` | `{ ... server state ... }` |
| `agent.listConversations` | iOS→Mac | `null` | `[{ id, title, updatedAt }]` |
| `webview.openURL` | iOS→Mac | `{ url: string }` | `null` |
| `webview.reload` | iOS→Mac | `null` | `null` |
| `settings.set` | iOS→Mac | `{ key: string, value: any }` | `null` |
| `settings.get` | iOS→Mac | `{ key: string }` | `{ value: any }` |

### `commandResponse` — Mac → iPhone

```json
{
  "id": "msg-2",
  "protocolVersion": 1,
  "kind": "commandResponse",
  "payload": {
    "type": "commandResponse",
    "data": {
      "inReplyTo": "msg-1",
      "result": { "runId": "r-99" },
      "error": null
    }
  }
}
```

If the command failed, `result` is null and `error` is `{ code, message }`.

### `event` — Mac → iPhone (push)

```json
{
  "id": "evt-1",
  "protocolVersion": 1,
  "kind": "event",
  "payload": {
    "type": "event",
    "data": {
      "topic": "agent.run.delta",
      "body": { "runId": "r-99", "delta": "Hello, " }
    }
  }
}
```

**Well-known topics:**

| Topic | Body |
| --- | --- |
| `agent.log` | `{ line: string, level: "info"|"warn"|"error" }` |
| `agent.run.delta` | `{ runId: string, delta: string }` |
| `agent.run.done` | `{ runId: string, finalText: string }` |
| `state.changed` | `{ key: string, value: any }` |

### `capabilityRequest` — Mac → iPhone

The Mac asks the iPhone to invoke a native iOS API. The iPhone consults its `CapabilityRegistry`, runs permission gating, performs the call, and replies with `capabilityResponse`.

```json
{
  "id": "cap-1",
  "protocolVersion": 1,
  "kind": "capabilityRequest",
  "payload": {
    "type": "capabilityRequest",
    "data": {
      "capability": "camera",
      "method": "takePhoto",
      "params": null
    }
  }
}
```

### `capabilityResponse` — iPhone → Mac

```json
{
  "id": "cap-2",
  "protocolVersion": 1,
  "kind": "capabilityResponse",
  "payload": {
    "type": "capabilityResponse",
    "data": {
      "inReplyTo": "cap-1",
      "result": { "dataURL": "data:image/jpeg;base64,..." },
      "error": null
    }
  }
}
```

### `authRotated` — Mac → iPhone (once per pairing)

Sent exactly once, immediately after the first successful handshake on a newly-paired device. Replaces the QR-baked token with a fresh one.

```json
{
  "id": "rot-1",
  "protocolVersion": 1,
  "kind": "authRotated",
  "payload": {
    "type": "authRotated",
    "data": {
      "newDeviceToken": "fresh-opaque-string",
      "oldTokenValidUntil": "2026-05-19T20:00:00Z"
    }
  }
}
```

The iPhone persists `newDeviceToken` via `PairedDeviceStore.replaceToken` and uses it on every subsequent connection. `oldTokenValidUntil` (optional ISO-8601) lets the Mac honour the old token for a short grace period so the current connection doesn't drop mid-stream.

### `ping` / `pong`

Either side sends `ping` at most every 25 s while idle. Receivers reply immediately with `pong`. Three missed `pong`s = connection treated as dead.

### `error`

Either side may emit an unsolicited `error` to signal a protocol-level problem. If it's in reply to a specific message, set `inReplyTo` to that message's `id`.

**Reserved error codes:**

| Code | Meaning |
| --- | --- |
| `unsupported_version` | `protocolVersion` outside server's supported range |
| `unauthenticated` | Token missing/invalid |
| `unknown_command` | Mac doesn't recognize the command name |
| `unknown_capability` | iPhone doesn't have that capability registered |
| `invalid_payload` | JSON shape doesn't match the kind |
| `internal_error` | Catch-all for unexpected server-side failures |

---

## Capability surface (iPhone → exposed to Mac/JS)

| Capability | Methods | Notes |
| --- | --- | --- |
| `camera` | `takePhoto`, `scanQR` | TODO: full implementation |
| `location` | `getCurrent`, `startUpdates`, `stopUpdates` | `getCurrent` done; updates streamed as `event` |
| `contacts` | `search` | params `{ query: string }` |
| `notifications` | `schedule`, `cancel` | local notifications only (push handled separately) |
| `share` | `present` | no permission needed |
| `biometrics` | `authenticate` | params `{ reason: string }` |

The same surface is exposed to hermes-webui via the JS bridge — see [JSBridge.swift](../Sources/HermesWebView/JSBridge.swift) for the method-routing rules:

```js
// from inside hermes-webui:
const photo = await window.hermes.invoke("capability.camera.takePhoto");
const runId = await window.hermes.invoke("bridge.agent.runPrompt", { prompt: "..." });
```

---

## Mac-side pairing UX

The pairing entry point must NOT be buried in Preferences. See [MAC_PAIRING_UX.md](MAC_PAIRING_UX.md) for the full UX spec — short version: menubar item at the top, global hotkey ⇧⌘P, and a toolbar button on the browser window, all opening the same dedicated pairing window. Target latency from "Mac awake" to "QR on screen" is ≤ 2 seconds via the primary path.

## What the Mac must build

`hermes-swift-mac` does not yet ship a `BridgeServer`. Required pieces:

1. **TLS keypair generation** at first launch — self-signed leaf cert, persistent across runs. SHA-256 fingerprint of the DER-encoded leaf is the value baked into pairing QRs (lowercase hex, no colons).
2. **`wss://` WebSocket listener** on a chosen port (configurable), serving `/v1/bridge`. Reject `ws://` (no TLS) in production builds.
3. **Bonjour publisher** for `_hermes._tcp` with TXT record matching the format above.
4. **QR pairing flow** — generate `PairingPayload`, render QR, persist issued device tokens. **Issue a single-use token in the QR**; rotate it via `authRotated` on first successful handshake.
5. **Token rotation** — after the first successful handshake on a newly-paired device, send `authRotated` with a freshly-minted token. Honour the old token for a short grace window (suggest 60 s) to avoid dropping the live connection.
6. **Command dispatcher** — table of `command name → async handler`.
7. **Event emitter** — push agent state changes to all connected iPhones.

The iOS BridgeClient is the source of truth for the wire format; mirror its types when implementing the server. The fingerprint hash function is exposed as `FingerprintPinner.fingerprint(ofDER:)` for unit-test parity between client and server.
