// ---------------------------------------------------------------------------
// ice.js — ephemeral TURN/STUN credentials for WebRTC ICE
//
// Produces short-lived coturn credentials using the standard "TURN REST API"
// long-term-credential mechanism (coturn `use-auth-secret` + `static-auth-secret`):
//
//   username = "<unix-expiry>:<accountId>"
//   password = base64( HMAC_SHA1( TURN_SHARED_SECRET, username ) )
//
// coturn validates the HMAC itself, so the shared secret never leaves the server
// and the app never ships static TURN credentials.
//
// Deployment is cgNAT / CloudGate tunnel: relay over UDP will not traverse a
// TLS-only tunnel, so TURN-over-TLS (turns:) and TURN-over-TCP are emitted FIRST.
// ICE still prefers any working direct (host/srflx) path automatically by
// candidate priority — relay is only used when no direct path validates.
// ---------------------------------------------------------------------------

const crypto = require('crypto');

const TURN_SHARED_SECRET = process.env.TURN_SHARED_SECRET || '';
const TURN_HOST = process.env.TURN_HOST || process.env.PUBLIC_HOST || '';
const TURN_PORT = parseInt(process.env.TURN_PORT, 10) || 3478;
const TURN_TLS_PORT = parseInt(process.env.TURN_TLS_PORT, 10) || 5349;
const TURN_TTL = parseInt(process.env.TURN_TTL, 10) || 3600; // 1h
// "tls-first" (cgNAT default) | "udp-first" (public-IP) — controls ordering only.
const TURN_TRANSPORT = (process.env.TURN_TRANSPORT || 'tls-first').toLowerCase();

/**
 * Generate an iceServers list with ephemeral TURN credentials for an account.
 * Returns { iceServers, ttl }. If TURN is not configured, returns STUN-only.
 */
function getIceServers(accountId) {
  // STUN: prefer the project's own coturn (no third-party leak of who connects),
  // with a public fallback so direct/srflx still works if coturn is unreachable.
  const iceServers = [];

  if (TURN_HOST) {
    iceServers.push({ urls: `stun:${TURN_HOST}:${TURN_PORT}` });
  }
  iceServers.push({ urls: 'stun:stun.l.google.com:19302' });

  if (TURN_HOST && TURN_SHARED_SECRET) {
    const expiry = Math.floor(Date.now() / 1000) + TURN_TTL;
    const username = `${expiry}:${accountId}`;
    const credential = crypto
      .createHmac('sha1', TURN_SHARED_SECRET)
      .update(username)
      .digest('base64');

    const tcp = { urls: `turn:${TURN_HOST}:${TURN_PORT}?transport=tcp`, username, credential };
    const tls = { urls: `turns:${TURN_HOST}:${TURN_TLS_PORT}?transport=tcp`, username, credential };
    const udp = { urls: `turn:${TURN_HOST}:${TURN_PORT}?transport=udp`, username, credential };

    if (TURN_TRANSPORT === 'udp-first') {
      iceServers.push(udp, tcp, tls);
    } else {
      // cgNAT / CloudGate: TLS and TCP relay first (survive a TLS-only tunnel).
      iceServers.push(tls, tcp, udp);
    }
  }

  return { iceServers, ttl: TURN_TTL };
}

module.exports = { getIceServers };
