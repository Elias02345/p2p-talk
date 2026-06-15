// ---------------------------------------------------------------------------
// ice.js — ICE (STUN/TURN) configuration for WebRTC, provider-flexible.
//
// Deployment is cgNAT / CloudGate (a Cloudflare Tunnel manager), which carries
// only HTTP/HTTPS/WebSocket. A *self-hosted* TURN (raw UDP/TCP) cannot traverse
// that tunnel, so TURN_MODE selects how the relay fallback is provided:
//
//   coturn     — self-hosted coturn with ephemeral HMAC creds (needs a publicly
//                reachable TURN port; e.g. a small VPS or CloudGate raw-TCP).
//   cloudflare — Cloudflare's managed TURN (rtc.live.cloudflare.com). Works
//                behind cgNAT with NO public IP — the recommended relay here.
//   static     — any hosted TURN via fixed URLs + credentials.
//   none       — STUN only (direct P2P works in most networks; no relay).
//
// ICE always prefers a direct path; relay is only the fallback.
// ---------------------------------------------------------------------------

const crypto = require('crypto');

const TURN_MODE = (process.env.TURN_MODE || 'coturn').toLowerCase();

// coturn
const TURN_SHARED_SECRET = process.env.TURN_SHARED_SECRET || '';
const TURN_HOST = process.env.TURN_HOST || process.env.PUBLIC_HOST || '';
const TURN_PORT = parseInt(process.env.TURN_PORT, 10) || 3478;
const TURN_TLS_PORT = parseInt(process.env.TURN_TLS_PORT, 10) || 5349;
const TURN_TTL = parseInt(process.env.TURN_TTL, 10) || 3600;
const TURN_TRANSPORT = (process.env.TURN_TRANSPORT || 'tls-first').toLowerCase();

// cloudflare
const CF_TURN_KEY_ID = process.env.CF_TURN_KEY_ID || '';
const CF_TURN_API_TOKEN = process.env.CF_TURN_API_TOKEN || '';

// static
const STATIC_TURN_URLS = (process.env.TURN_URLS || '').split(',').map((s) => s.trim()).filter(Boolean);
const STATIC_TURN_USERNAME = process.env.TURN_USERNAME || '';
const STATIC_TURN_CREDENTIAL = process.env.TURN_CREDENTIAL || '';

const PUBLIC_STUN = { urls: 'stun:stun.l.google.com:19302' };

function coturnServers(accountId) {
  const iceServers = [];
  if (TURN_HOST) iceServers.push({ urls: `stun:${TURN_HOST}:${TURN_PORT}` });
  iceServers.push(PUBLIC_STUN);

  if (TURN_HOST && TURN_SHARED_SECRET) {
    const expiry = Math.floor(Date.now() / 1000) + TURN_TTL;
    const username = `${expiry}:${accountId}`;
    const credential = crypto.createHmac('sha1', TURN_SHARED_SECRET).update(username).digest('base64');
    const tcp = { urls: `turn:${TURN_HOST}:${TURN_PORT}?transport=tcp`, username, credential };
    const tls = { urls: `turns:${TURN_HOST}:${TURN_TLS_PORT}?transport=tcp`, username, credential };
    const udp = { urls: `turn:${TURN_HOST}:${TURN_PORT}?transport=udp`, username, credential };
    iceServers.push(...(TURN_TRANSPORT === 'udp-first' ? [udp, tcp, tls] : [tls, tcp, udp]));
  }
  return { iceServers, ttl: TURN_TTL };
}

function staticServers() {
  const iceServers = [PUBLIC_STUN];
  if (STATIC_TURN_URLS.length) {
    iceServers.push({
      urls: STATIC_TURN_URLS,
      username: STATIC_TURN_USERNAME,
      credential: STATIC_TURN_CREDENTIAL,
    });
  }
  return { iceServers, ttl: TURN_TTL };
}

// Cloudflare's managed TURN: a back-end mints short-lived creds with the TURN key.
async function cloudflareServers() {
  if (!CF_TURN_KEY_ID || !CF_TURN_API_TOKEN) {
    return { iceServers: [PUBLIC_STUN], ttl: 0 };
  }
  try {
    const res = await fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${CF_TURN_KEY_ID}/credentials/generate-ice-servers`,
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${CF_TURN_API_TOKEN}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ ttl: TURN_TTL }),
      }
    );
    if (!res.ok) {
      console.error('[ICE] Cloudflare TURN error:', res.status);
      return { iceServers: [PUBLIC_STUN], ttl: 0 };
    }
    const data = await res.json();
    const servers = Array.isArray(data.iceServers) ? data.iceServers : [data.iceServers];
    return { iceServers: servers, ttl: TURN_TTL };
  } catch (err) {
    console.error('[ICE] Cloudflare TURN fetch failed:', err.message);
    return { iceServers: [PUBLIC_STUN], ttl: 0 };
  }
}

/** Returns { iceServers, ttl }. Async (the cloudflare provider calls an API). */
async function getIceServers(accountId) {
  switch (TURN_MODE) {
    case 'none':
      return { iceServers: [PUBLIC_STUN], ttl: 0 };
    case 'static':
      return staticServers();
    case 'cloudflare':
      return cloudflareServers();
    case 'coturn':
    default:
      return coturnServers(accountId);
  }
}

module.exports = { getIceServers, TURN_MODE };
