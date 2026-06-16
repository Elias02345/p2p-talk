# p2p-talk 🎙️

> Secure, hands-free peer-to-peer voice for the **gym** and the **motorcycle intercom** — talk through your headphones **without losing music quality**, and **without it behaving like a phone call**.

p2p-talk connects two or more phones over encrypted WebRTC. Voice Activity
Detection (VAD) transmits **only when you actually speak**; the partner's voice
is **mixed into your music stream** at full A2DP quality (never the loudspeaker,
never an HFP downgrade). If a direct P2P path fails, audio falls back through a
self-hosted relay **seamlessly** — and the app keeps trying to restore P2P.

## ✨ Features

- **🎤 Voice activation (Silero VAD)** — only speech is sent; silence and gym/road noise are not.
- **🎧 No music-quality loss** — voice is mixed into the A2DP **media** stream (Android stays in `MODE_NORMAL`, no HFP/SCO). Gym mode captures via the phone mic; intercom mode uses full helmet SCO.
- **📱 Not a call** — no ringing, no accept dialog; known-partner channels open automatically.
- **🔁 Seamless relay fallback** — ICE prefers direct P2P; falls back to TURN relay only when needed, and auto-restarts ICE to regain P2P. The user never notices the switch.
- **🔒 End-to-end encrypted** — DTLS-SRTP; the relay only forwards ciphertext. Account auth is a device-held Ed25519 key (no passwords); peers verify each other cryptographically (anti-MitM).
- **🌍 Bilingual** — English / Deutsch, switchable in-app.
- **👥 Group rooms**, **📍 gym geofencing**, **🔋 battery/data efficient** (Opus DTX, WS-ping latency, tuned GPS/BLE).

## 🏗️ Architecture

```
Flutter app (Android / iOS)
  ├─ AccountService     Ed25519 identity (BIP39 seed) + per-device subkey, challenge→JWT
  ├─ WebRTCService      multi-peer WebRTC, dynamic ICE (/api/ice), DTX, signed-fingerprint verify
  ├─ AudioManager       gym (A2DP media mix) vs intercom (SCO) routing
  ├─ VadService         Silero VAD gates the mic track
  └─ Connection/Geofence/BLE/Notification services

Node.js server  (self-hosted, headless, behind CloudGate/cgNAT)
  ├─ server.js          Express + ws: account/auth, /api/ice, signaling, presence, rooms
  ├─ lib/auth.js        Ed25519 verify, challenge store, JWT
  ├─ lib/ice.js         ephemeral coturn (TURN REST) credentials
  └─ SQLite (sacred path)

coturn                  TURN/STUN relay (TCP/TLS first for cgNAT)
```

Media stays end-to-end encrypted even over the relay (see [docs/UPDATE_RULES.md](server/docs/UPDATE_RULES.md) and the security notes below).

## 📱 App — build

Requires Flutter (stable). Android builds on any OS; iOS requires macOS/Xcode.

```bash
cd app
flutter pub get
flutter gen-l10n
flutter analyze
flutter build apk --release --split-per-abi   # signed if android/key.properties exists
flutter build appbundle --release
```

Release signing reads `android/key.properties` + the keystore (both gitignored —
**never commit them**). On first launch the user creates an account (username +
auto-generated recovery phrase) and enters the server URL, e.g.
`https://p2p-talk.example.com` — or skips it to use the app without an account.

## 🖥️ Server — one-command install (Ubuntu/Debian)

Deployed headless behind **CloudGate** (cgNAT tunnel). No public IP required.

```bash
git clone https://github.com/Elias02345/p2p-talk.git
cd p2p-talk/server
sudo bash install.sh --public-host p2p-talk.example.com
```

The installer is idempotent: installs Docker, generates `JWT_SECRET` and
`TURN_SHARED_SECRET` into `.env`, renders the coturn config, builds and starts
the stack, and registers systemd units (including a 10-minute **auto-update** timer).

**Behind cgNAT (no public IP)** — see [server/docs/DEPLOYMENT_CLOUDFLARE.md](server/docs/DEPLOYMENT_CLOUDFLARE.md).
Cloudflare Tunnel / CloudGate carries the signaling over **HTTP long-poll**
(`https://`, no WebSocket upgrade needed); for the relay
fallback set `TURN_MODE=cloudflare` (Cloudflare managed TURN — works behind cgNAT,
no public IP). Direct P2P calls work over STUN without any relay.

```bash
# cgNAT box, signaling via CloudGate + Cloudflare managed TURN:
sudo bash install.sh --public-host p2p-talk.example.com \
     --turn-mode cloudflare --cf-turn-key-id <id> --cf-turn-api-token <token>
```

Operations:

```bash
sudo bash update.sh            # check → backup → rebuild → health-check → rollback on failure
sudo bash revert-update.sh     # manual rollback to the last backup
sudo bash doctor.sh --repair   # diagnose & repair
```

### Configuration (`server/.env`)

| Key | Purpose |
|---|---|
| `PORT` | Signaling port (bound to 127.0.0.1 in prod) |
| `PUBLIC_HOST` | Public domain clients connect to |
| `JWT_SECRET` | Session-token signing secret (generated) |
| `TURN_SHARED_SECRET` | Shared with coturn for ephemeral creds (generated) |
| `TURN_MODE` | Relay provider: `coturn` / `cloudflare` (cgNAT) / `static` / `none` |
| `CF_TURN_KEY_ID` / `CF_TURN_API_TOKEN` | Cloudflare managed TURN (cgNAT, no public IP) |
| `TURN_HOST` / `TURN_PORT` / `TURN_TLS_PORT` | coturn endpoints |
| `TURN_TRANSPORT` | `tls-first` (cgNAT) or `udp-first` (public IP) |
| `TUNNEL_TOKEN` | Optional bundled cloudflared tunnel token |
| `UPDATE_BRANCH` | Auto-update channel (`main` / `dev`) |
| `DB_PATH` | SQLite path (**sacred** — never touched by the updater) |

## 🔐 Security model

- **Transport**: HTTP long-poll signaling over `https://` (or `http://` on a trusted LAN); TLS terminated by CloudGate/proxy.
- **Accounts**: Ed25519 identity derived from a BIP39 seed; each device enrolls its
  own subkey authorized by the identity key. Auth is challenge–response (no passwords);
  the private key never leaves the device's secure storage. Lost devices are revocable.
- **Media**: DTLS-SRTP end-to-end. coturn relays only ciphertext and cannot listen in.
- **Anti-MitM**: peers sign their DTLS fingerprint + authorization chain so a
  compromised signaling server cannot inject its own key. Optional safety number.

## 📄 License

See repository. Developer: Elias Kanakidis ([@Elias02345](https://github.com/Elias02345)).
