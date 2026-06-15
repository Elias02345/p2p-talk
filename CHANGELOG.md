# Changelog

All notable changes to p2p-talk are documented here.

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
