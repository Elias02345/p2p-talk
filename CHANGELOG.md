# Changelog

All notable changes to p2p-talk are documented here.

## [2.0.2] — 2026-06-16

### Added / Changed
- **HTTP long-poll signaling** (`POST /api/rtc/poll` + `/api/rtc/send`) replaces the
  WebSocket transport on the client, so signaling traverses CloudGate / any
  HTTP-only Cloudflare Tunnel (no `ws://` upgrade required). The WebSocket server
  endpoint is retained for compatibility; both share one routing path.
- App connects over `https://<host>` (or `http://<ip>:<port>` on a LAN).
- **Use without an account**: onboarding now offers a local mode so the app opens
  without a server; account-dependent features are disabled until you set one up
  (Settings → Set up account).
- Clarified installer/docs: `--public-host` is a hostname (CloudGate maps it to
  `http://<server-ip>:<port>`), not a "CloudGate IP".

## [2.0.1] — 2026-06-15

### Added / Changed
- **Plain HTTP / `ws://` over a CloudGate IP:port** — no domain or TLS required.
  The signaling server is exposed on `0.0.0.0:PORT` (configurable via
  `SIGNALING_BIND`) so a separate CloudGate VM can forward `<ip>:<port>` to it.
- App now permits cleartext `ws://`/`http://` (Android `usesCleartextTraffic`,
  iOS ATS) and defaults onboarding to `ws://<ip>:<port>`.
- Relay provider selectable via `TURN_MODE` (`coturn` / `cloudflare` / `static` /
  `none`); Cloudflare managed TURN documented for cgNAT without a public IP.
- Build-time `DEFAULT_SERVER_URL` so a released APK can ship preconfigured.

### Security note
`ws://` is unencrypted on the wire; media remains end-to-end encrypted (DTLS-SRTP)
and calls are MitM-protected, but `wss://` via a domain is preferred for token privacy.

## [2.0.0] — 2026-06-15

Major release. Renamed from **GymTalk** to **p2p-talk** and hardened end to end.

### Added
- **Account system** with public/private-key authentication (Ed25519), BIP39
  recovery phrase, per-device subkeys, and passwordless challenge–response
  sessions (short-lived JWT). Private keys never leave the device.
- **Server relay fallback** via self-hosted coturn with ephemeral HMAC
  credentials served from an authenticated `GET /api/ice`. ICE prefers a direct
  P2P path automatically and re-establishes it after a relay fallback (ICE restart).
- **Cryptographic anti-MitM**: peers sign their DTLS fingerprint + an
  identity→device authorization chain; a malicious signaling server cannot
  substitute keys. Optional verbal safety-number.
- **Bilingual UI** (English default, Deutsch) with an in-app language switch.
- **Headless self-hosting stack**: `install.sh`, `update.sh` (backup → rebuild →
  health-check → automatic rollback → state file), `revert-update.sh`,
  `doctor.sh`, systemd units, a 10-minute auto-update timer, Docker Compose
  (CloudGate/cgNAT default + host-network variant) and a coturn config template.
- Opus **DTX** + low bitrate cap for data efficiency; an Android **foreground
  service** so a session survives screen-lock.

### Changed
- **Audio engine**: the partner's voice is mixed into the existing A2DP **media**
  stream at full quality — no HFP/SCO downgrade, never the loudspeaker, and it
  does **not** behave like a phone call. Transmission is **VAD-gated** (speech
  only; silence and noise are never sent).
- No ringing/accept dialog — known-partner channels open automatically.
- WebSocket and REST now require authentication.
- SQLite driver upgraded to `sqlite3` v6 (0 npm vulnerabilities).

### Security
- All signaling is authenticated and runs over `wss://` (TLS terminated by
  CloudGate / reverse proxy). Media is end-to-end encrypted (DTLS-SRTP); the
  relay only forwards ciphertext and cannot eavesdrop.
