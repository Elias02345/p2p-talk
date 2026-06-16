# Deploying p2p-talk behind cgNAT (Cloudflare Tunnel / CloudGate)

p2p-talk runs fully behind cgNAT with **no public IP**. This guide covers the
two pieces that need public reachability — **signaling** and the **relay** — and
how each is solved over the Cloudflare ecosystem.

## The key fact

A Cloudflare Tunnel (and CloudGate, which manages `cloudflared`) forwards
**HTTP/HTTPS/WebSocket only**. That is perfect for signaling, but a *self-hosted*
TURN relay needs raw UDP/TCP that the tunnel cannot carry to arbitrary clients.

| Piece | Transport | Works over Cloudflare Tunnel / CloudGate? |
|---|---|---|
| Signaling (`wss://`, `/api/*`) | HTTPS/WebSocket | ✅ yes |
| Direct P2P calls (STUN) | UDP between phones | ✅ yes (no server needed) |
| Relay fallback (TURN) | UDP/TCP from phones | ❌ not via the tunnel — use one of the relay options below |

In practice most calls connect **directly** with STUN alone. The relay is only the
guaranteed fallback for strict/symmetric NAT.

## 1. Signaling — Cloudflare Tunnel

### Option A — CloudGate VM forwards IP:port over plain HTTP (your setup)
CloudGate runs on its own VM and forwards a public IP:port to this server.
1. `sudo PUBLIC_HOST=<cloudgate-ip> bash install.sh` — the signaling server listens
   on `0.0.0.0:3000` (set `SIGNALING_BIND` to change), reachable from the CloudGate VM.
2. In CloudGate, forward `<cloudgate-ip>:3000` → `<this-server-ip>:3000` (plain HTTP).
3. App onboarding: `ws://<cloudgate-ip>:3000`.

> ws:// is **unencrypted on the wire**. The media stays end-to-end encrypted
> (DTLS-SRTP) and calls are MitM-protected by the signed-fingerprint chain, but
> for token privacy prefer `wss://` via a domain when you can (Option B).

### Option B — bundled cloudflared
1. Create a tunnel in the Cloudflare dashboard, copy the **tunnel token**, and map
   `p2p-talk.<your-domain>` → `http://localhost:3000`.
2. `sudo TUNNEL_TOKEN=<token> PUBLIC_HOST=p2p-talk.<your-domain> bash install.sh`
   — the stack runs a `cloudflared` container automatically (compose profile `tunnel`).

## 2. Relay — pick a `TURN_MODE`

Set in `server/.env` (or pass to `install.sh`):

### `cloudflare` — recommended for cgNAT (no public IP, no VPS)
Cloudflare's managed TURN works behind cgNAT and is reachable globally.
1. Dashboard → **Realtime → TURN** → create a TURN key.
2. ```
   TURN_MODE=cloudflare
   CF_TURN_KEY_ID=<key id>
   CF_TURN_API_TOKEN=<api token>
   ```
   The server mints short-lived credentials per call via the Cloudflare API; the
   key/token never leave the server.

### `coturn` — fully self-hosted (needs a publicly reachable TURN port)
Only viable if you have a public IP **or** a tunnel that forwards raw TCP. coturn
is bundled in the stack; expose `5349/tcp` (TLS) to the internet. Not reachable
through a plain Cloudflare Tunnel.

### `static` — any other hosted TURN
```
TURN_MODE=static
TURN_URLS=turns:turn.example.com:5349?transport=tcp
TURN_USERNAME=...
TURN_CREDENTIAL=...
```

### `none` — STUN only
Direct P2P only; no relay fallback. Fine for testing or LAN use.

## 3. App

On first launch the user enters `wss://p2p-talk.<your-domain>`. To ship a
preconfigured ("standalone") APK that needs no manual entry:

```bash
flutter build apk --release --split-per-abi \
  --dart-define=DEFAULT_SERVER_URL=wss://p2p-talk.<your-domain>
```

## Recommended cgNAT setup (summary)

CloudGate for signaling + `TURN_MODE=cloudflare` for the relay = the whole system
runs on your cgNAT box with no public IP and a guaranteed relay fallback.
