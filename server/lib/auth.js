// ---------------------------------------------------------------------------
// auth.js — public/private-key account authentication
//
// Accounts are identified by an Ed25519 *identity* keypair (seed-derived on the
// client). Each device enrolls its own Ed25519 *device subkey*, authorized by a
// signature from the identity key. Day-to-day authentication is a stateless
// challenge–response: the server hands out a nonce, the device signs it with its
// device private key, and the server verifies the signature against the stored
// device public key and issues a short-lived session JWT.
//
// No passwords are ever transmitted or stored; private keys never leave the
// device. The server only ever sees public keys and signatures.
// ---------------------------------------------------------------------------

const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || '';
const JWT_TTL_SECONDS = parseInt(process.env.JWT_TTL_SECONDS, 10) || 86400; // 24h
const CHALLENGE_TTL_MS = parseInt(process.env.CHALLENGE_TTL_MS, 10) || 120000; // 2 min

// Fail fast in production if the signing secret is missing — never fall back to
// a default (see project secret-handling rules).
if (!JWT_SECRET && process.env.NODE_ENV === 'production') {
  throw new Error('JWT_SECRET is required in production but is not set.');
}
const EFFECTIVE_SECRET = JWT_SECRET || 'dev-only-insecure-secret-change-me';

// ---------------------------------------------------------------------------
// Ed25519 helpers
// ---------------------------------------------------------------------------

// DER SPKI prefix for an Ed25519 public key (RFC 8410). Raw 32-byte keys coming
// from the client are wrapped with this so Node's crypto can consume them.
const ED25519_SPKI_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');

/**
 * Build a Node KeyObject from a raw 32-byte Ed25519 public key (base64).
 * Returns null if the input is malformed.
 */
function publicKeyFromRaw(b64) {
  try {
    const raw = Buffer.from(b64, 'base64');
    if (raw.length !== 32) return null;
    const der = Buffer.concat([ED25519_SPKI_PREFIX, raw]);
    return crypto.createPublicKey({ key: der, format: 'der', type: 'spki' });
  } catch {
    return null;
  }
}

/**
 * Verify an Ed25519 signature.
 * @param {string} publicKeyB64 raw 32-byte public key, base64
 * @param {Buffer|string} message the signed message
 * @param {string} signatureB64 64-byte signature, base64
 * @returns {boolean}
 */
function verifySignature(publicKeyB64, message, signatureB64) {
  const key = publicKeyFromRaw(publicKeyB64);
  if (!key) return false;
  try {
    const msg = Buffer.isBuffer(message) ? message : Buffer.from(message, 'utf8');
    const sig = Buffer.from(signatureB64, 'base64');
    if (sig.length !== 64) return false;
    return crypto.verify(null, msg, key, sig);
  } catch {
    return false;
  }
}

/**
 * Derive a stable account id from the identity public key, so a device that
 * restores from the seed phrase re-derives the same account id.
 */
function accountIdFromIdentityKey(identityPublicKeyB64) {
  const raw = Buffer.from(identityPublicKeyB64, 'base64');
  return crypto.createHash('sha256').update(raw).digest('base64url').slice(0, 32);
}

// ---------------------------------------------------------------------------
// Challenge store (in-memory, single-instance)
// ---------------------------------------------------------------------------

// key: `${accountId}:${devicePublicKey}` -> { nonce, expires }
const challenges = new Map();

function issueChallenge(accountId, devicePublicKey) {
  const nonce = crypto.randomBytes(32).toString('base64');
  challenges.set(`${accountId}:${devicePublicKey}`, {
    nonce,
    expires: Date.now() + CHALLENGE_TTL_MS,
  });
  return nonce;
}

/**
 * Consume a challenge (one-time use) and return the expected nonce, or null if
 * none/expired.
 */
function consumeChallenge(accountId, devicePublicKey) {
  const k = `${accountId}:${devicePublicKey}`;
  const entry = challenges.get(k);
  challenges.delete(k);
  if (!entry || entry.expires < Date.now()) return null;
  return entry.nonce;
}

// Periodically drop expired challenges so the map can't grow unbounded.
const challengeSweeper = setInterval(() => {
  const now = Date.now();
  for (const [k, v] of challenges.entries()) {
    if (v.expires < now) challenges.delete(k);
  }
}, 60000);
if (challengeSweeper.unref) challengeSweeper.unref();

// ---------------------------------------------------------------------------
// Session tokens (JWT)
// ---------------------------------------------------------------------------

function issueToken(accountId, devicePublicKey) {
  return jwt.sign(
    { sub: accountId, dev: devicePublicKey },
    EFFECTIVE_SECRET,
    { expiresIn: JWT_TTL_SECONDS }
  );
}

function verifyToken(token) {
  try {
    return jwt.verify(token, EFFECTIVE_SECRET);
  } catch {
    return null;
  }
}

/**
 * Express middleware: require a valid Bearer token. Sets req.account = { id, device }.
 */
function requireAuth(req, res, next) {
  const header = req.headers['authorization'] || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  const decoded = token ? verifyToken(token) : null;
  if (!decoded) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  req.account = { id: decoded.sub, device: decoded.dev };
  next();
}

module.exports = {
  JWT_TTL_SECONDS,
  verifySignature,
  accountIdFromIdentityKey,
  issueChallenge,
  consumeChallenge,
  issueToken,
  verifyToken,
  requireAuth,
};
