// Load environment variables before anything else
require('dotenv').config();

const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');
const db = require('./db');
const auth = require('./lib/auth');
const ice = require('./lib/ice');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';
const WS_HEARTBEAT_INTERVAL = parseInt(process.env.WS_HEARTBEAT_INTERVAL, 10) || 30000;
const SERVER_VERSION = '2.0.0';

const startTime = Date.now();

// ---------------------------------------------------------------------------
// Express app setup
// ---------------------------------------------------------------------------
const app = express();
app.set('trust proxy', 1); // behind CloudGate / reverse proxy
app.use(helmet());
app.use(cors({ origin: CORS_ORIGIN }));
app.use(express.json({ limit: '64kb' }));

if (NODE_ENV === 'development') {
  app.use(morgan('dev'));
}

// General API rate limit
const apiLimiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 60000,
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS, 10) || 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' },
});
app.use('/api/', apiLimiter);

// Stricter limiter for auth/enrollment endpoints (anti-bruteforce / abuse)
const authLimiter = rateLimit({
  windowMs: parseInt(process.env.AUTH_RATE_LIMIT_WINDOW_MS, 10) || 60000,
  max: parseInt(process.env.AUTH_RATE_LIMIT_MAX, 10) || 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many authentication attempts, slow down.' },
});

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

// ws -> { accountId, device }
const sockets = new Map();
// accountId -> Set<ws>   (an account may have several devices online)
const accountSockets = new Map();
// roomId -> Set<accountId>
const rooms = new Map();

function registerSocket(ws, accountId, device) {
  sockets.set(ws, { accountId, device });
  if (!accountSockets.has(accountId)) accountSockets.set(accountId, new Set());
  accountSockets.get(accountId).add(ws);
}

function unregisterSocket(ws) {
  const meta = sockets.get(ws);
  sockets.delete(ws);
  if (!meta) return null;
  const set = accountSockets.get(meta.accountId);
  if (set) {
    set.delete(ws);
    if (set.size === 0) accountSockets.delete(meta.accountId);
  }
  return meta;
}

function isOnline(accountId) {
  const set = accountSockets.get(accountId);
  return !!set && set.size > 0;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Haversine distance in metres. */
function getDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3;
  const f1 = (lat1 * Math.PI) / 180;
  const f2 = (lat2 * Math.PI) / 180;
  const df = ((lat2 - lat1) * Math.PI) / 180;
  const dl = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(df / 2) * Math.sin(df / 2) +
    Math.cos(f1) * Math.cos(f2) * Math.sin(dl / 2) * Math.sin(dl / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function sendWS(ws, payload) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    try {
      ws.send(JSON.stringify(payload));
      return true;
    } catch (err) {
      console.error('[WS] send error:', err.message);
      return false;
    }
  }
  return false;
}

/** Send a payload to every online device (socket) of an account. */
function sendToAccount(accountId, payload, exceptWs = null) {
  const set = accountSockets.get(accountId);
  if (!set) return false;
  let sent = false;
  for (const ws of set) {
    if (ws !== exceptWs) sent = sendWS(ws, payload) || sent;
  }
  return sent;
}

async function notifyContactsStatus(accountId, event) {
  try {
    const contacts = await db.query(
      `SELECT contact_id AS id FROM contacts WHERE user_id = ? AND status = 'accepted'`,
      [accountId]
    );
    const user = await db.get('SELECT username, gym_id FROM users WHERE id = ?', [accountId]);
    if (!user) return;
    for (const c of contacts) {
      if (isOnline(c.id)) {
        sendToAccount(c.id, {
          type: 'contact_status',
          contactId: accountId,
          username: user.username,
          event,
          gymId: user.gym_id,
          isOnline: event !== 'offline',
        });
      }
    }
  } catch (error) {
    console.error('[Notify] error:', error);
  }
}

function broadcastToRoom(roomId, senderAccountId, payload) {
  const members = rooms.get(roomId);
  if (!members) return;
  for (const memberId of members) {
    if (memberId !== senderAccountId) sendToAccount(memberId, payload);
  }
}

function removeFromAllRooms(accountId) {
  for (const [roomId, members] of rooms.entries()) {
    if (members.has(accountId)) {
      members.delete(accountId);
      broadcastToRoom(roomId, accountId, { type: 'room_member_left', roomId, userId: accountId });
      if (members.size === 0) rooms.delete(roomId);
    }
  }
}

/** Require that the authenticated account matches the :id route param. */
function ensureSelf(req, res, next) {
  if (req.account.id !== req.params.id) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  next();
}

// ---------------------------------------------------------------------------
// REST: health & stats (public)
// ---------------------------------------------------------------------------
app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    uptime: Math.floor((Date.now() - startTime) / 1000),
    connections: sockets.size,
    version: SERVER_VERSION,
  });
});

app.get('/api/stats', async (_req, res) => {
  try {
    const usersRow = await db.get('SELECT COUNT(*) AS count FROM users');
    const contactsRow = await db.get("SELECT COUNT(*) AS count FROM contacts WHERE status = 'accepted'");
    const gymsRow = await db.get('SELECT COUNT(*) AS count FROM gym_locations');
    res.json({
      connections: sockets.size,
      onlineAccounts: accountSockets.size,
      registeredUsers: usersRow ? usersRow.count : 0,
      acceptedContacts: contactsRow ? contactsRow.count : 0,
      gyms: gymsRow ? gymsRow.count : 0,
      activeRooms: rooms.size,
      uptime: Math.floor((Date.now() - startTime) / 1000),
      version: SERVER_VERSION,
    });
  } catch (error) {
    console.error('[API] stats error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// ---------------------------------------------------------------------------
// REST: account enrollment & authentication (public, rate-limited)
// ---------------------------------------------------------------------------

// Create (or look up) an account from its identity public key.
app.post('/api/account/register', authLimiter, async (req, res) => {
  const { username, identityPublicKey } = req.body || {};
  if (!username || !identityPublicKey) {
    return res.status(400).json({ error: 'Missing username or identityPublicKey' });
  }
  if (typeof username !== 'string' || username.length < 1 || username.length > 32) {
    return res.status(400).json({ error: 'Invalid username' });
  }
  const accountId = auth.accountIdFromIdentityKey(identityPublicKey);
  try {
    const existing = await db.get('SELECT id, username FROM users WHERE id = ?', [accountId]);
    if (existing) {
      // Idempotent: same identity key re-registering (e.g. seed restore).
      return res.json({ accountId, username: existing.username, existed: true });
    }
    // Username uniqueness (best-effort; first-come).
    const nameTaken = await db.get('SELECT id FROM users WHERE username = ?', [username]);
    if (nameTaken) {
      return res.status(409).json({ error: 'Username already taken' });
    }
    const now = Date.now();
    await db.run(
      `INSERT INTO users (id, username, last_seen, identity_public_key, created_at)
       VALUES (?, ?, ?, ?, ?)`,
      [accountId, username, now, identityPublicKey, now]
    );
    res.json({ accountId, username, existed: false });
  } catch (error) {
    console.error('[API] register error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Enroll a device subkey. Authorized by a signature from the account identity key
// over the device public key (proves the enroller holds the seed/identity key).
app.post('/api/account/device', authLimiter, async (req, res) => {
  const { accountId, devicePublicKey, authorizationSig, deviceLabel } = req.body || {};
  if (!accountId || !devicePublicKey || !authorizationSig) {
    return res.status(400).json({ error: 'Missing fields' });
  }
  try {
    const acct = await db.get('SELECT identity_public_key FROM users WHERE id = ?', [accountId]);
    if (!acct || !acct.identity_public_key) {
      return res.status(404).json({ error: 'Account not found' });
    }
    // The identity key must have signed the raw device public key.
    const ok = auth.verifySignature(acct.identity_public_key, devicePublicKey, authorizationSig);
    if (!ok) {
      return res.status(401).json({ error: 'Invalid authorization signature' });
    }
    const now = Date.now();
    await db.run(
      `INSERT INTO account_devices (account_id, device_public_key, authorization_sig, device_label, created_at, last_seen, revoked)
       VALUES (?, ?, ?, ?, ?, ?, 0)
       ON CONFLICT(account_id, device_public_key)
       DO UPDATE SET authorization_sig = excluded.authorization_sig, device_label = excluded.device_label, revoked = 0`,
      [accountId, devicePublicKey, authorizationSig, deviceLabel || null, now, now]
    );
    res.json({ success: true });
  } catch (error) {
    console.error('[API] device enroll error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Challenge–response step 1: request a nonce.
app.post('/api/auth/challenge', authLimiter, async (req, res) => {
  const { accountId, devicePublicKey } = req.body || {};
  if (!accountId || !devicePublicKey) {
    return res.status(400).json({ error: 'Missing fields' });
  }
  try {
    const device = await db.get(
      'SELECT revoked FROM account_devices WHERE account_id = ? AND device_public_key = ?',
      [accountId, devicePublicKey]
    );
    if (!device || device.revoked) {
      return res.status(404).json({ error: 'Device not enrolled' });
    }
    const nonce = auth.issueChallenge(accountId, devicePublicKey);
    res.json({ nonce });
  } catch (error) {
    console.error('[API] challenge error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Challenge–response step 2: verify the signature, issue a session token.
app.post('/api/auth/verify', authLimiter, async (req, res) => {
  const { accountId, devicePublicKey, signature } = req.body || {};
  if (!accountId || !devicePublicKey || !signature) {
    return res.status(400).json({ error: 'Missing fields' });
  }
  try {
    const device = await db.get(
      'SELECT revoked FROM account_devices WHERE account_id = ? AND device_public_key = ?',
      [accountId, devicePublicKey]
    );
    if (!device || device.revoked) {
      return res.status(404).json({ error: 'Device not enrolled' });
    }
    const nonce = auth.consumeChallenge(accountId, devicePublicKey);
    if (!nonce) {
      return res.status(401).json({ error: 'No active challenge' });
    }
    if (!auth.verifySignature(devicePublicKey, nonce, signature)) {
      return res.status(401).json({ error: 'Invalid signature' });
    }
    await db.run(
      'UPDATE account_devices SET last_seen = ? WHERE account_id = ? AND device_public_key = ?',
      [Date.now(), accountId, devicePublicKey]
    );
    const token = auth.issueToken(accountId, devicePublicKey);
    res.json({ token, expiresIn: auth.JWT_TTL_SECONDS });
  } catch (error) {
    console.error('[API] verify error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// ---------------------------------------------------------------------------
// REST: authenticated endpoints
// ---------------------------------------------------------------------------

// Ephemeral ICE servers (STUN + short-lived TURN credentials).
app.get('/api/ice', auth.requireAuth, (req, res) => {
  res.json(ice.getIceServers(req.account.id));
});

// List this account's enrolled devices.
app.get('/api/account/devices', auth.requireAuth, async (req, res) => {
  try {
    const devices = await db.query(
      `SELECT device_public_key, device_label, created_at, last_seen, revoked
       FROM account_devices WHERE account_id = ? ORDER BY created_at`,
      [req.account.id]
    );
    res.json(devices.map((d) => ({
      devicePublicKey: d.device_public_key,
      label: d.device_label,
      createdAt: d.created_at,
      lastSeen: d.last_seen,
      revoked: !!d.revoked,
      current: d.device_public_key === req.account.device,
    })));
  } catch (error) {
    console.error('[API] devices error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Revoke a device (lost phone). Authenticated by any non-revoked device of the account.
app.post('/api/account/device/revoke', auth.requireAuth, async (req, res) => {
  const { devicePublicKey } = req.body || {};
  if (!devicePublicKey) return res.status(400).json({ error: 'Missing devicePublicKey' });
  try {
    await db.run(
      'UPDATE account_devices SET revoked = 1 WHERE account_id = ? AND device_public_key = ?',
      [req.account.id, devicePublicKey]
    );
    res.json({ success: true });
  } catch (error) {
    console.error('[API] revoke error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Account-scoped settings blob (synchronized across the account's devices).
app.get('/api/account/settings', auth.requireAuth, async (req, res) => {
  try {
    const row = await db.get('SELECT settings_json FROM users WHERE id = ?', [req.account.id]);
    res.json({ settings: row && row.settings_json ? JSON.parse(row.settings_json) : {} });
  } catch (error) {
    console.error('[API] get settings error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.put('/api/account/settings', auth.requireAuth, async (req, res) => {
  const { settings } = req.body || {};
  if (typeof settings !== 'object' || settings === null) {
    return res.status(400).json({ error: 'Invalid settings' });
  }
  try {
    await db.run('UPDATE users SET settings_json = ? WHERE id = ?', [
      JSON.stringify(settings),
      req.account.id,
    ]);
    res.json({ success: true });
  } catch (error) {
    console.error('[API] put settings error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Resolve a username to an account id (for adding contacts).
app.get('/api/users/lookup', auth.requireAuth, async (req, res) => {
  const { username } = req.query;
  if (!username) return res.status(400).json({ error: 'Missing username' });
  try {
    const u = await db.get('SELECT id, username FROM users WHERE username = ?', [username]);
    if (!u) return res.status(404).json({ error: 'User not found' });
    res.json({ id: u.id, username: u.username });
  } catch (error) {
    console.error('[API] lookup error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Update location / gym check-in.
app.post('/api/users/:id/location', auth.requireAuth, ensureSelf, async (req, res) => {
  const { id } = req.params;
  const { latitude, longitude, gym_id } = req.body || {};
  try {
    await db.run(
      'UPDATE users SET latitude = ?, longitude = ?, gym_id = ?, last_seen = ? WHERE id = ?',
      [latitude, longitude, gym_id, Date.now(), id]
    );
    notifyContactsStatus(id, 'location_updated');
    res.json({ success: true });
  } catch (error) {
    console.error('[API] location error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Contacts list.
app.get('/api/users/:id/contacts', auth.requireAuth, ensureSelf, async (req, res) => {
  const { id } = req.params;
  try {
    const contacts = await db.query(
      `SELECT u.id, u.username, u.gym_id, u.last_seen, c.status
       FROM contacts c JOIN users u ON u.id = c.contact_id
       WHERE c.user_id = ?`,
      [id]
    );
    res.json(contacts.map((c) => ({
      id: c.id,
      username: c.username,
      gymId: c.gym_id,
      isOnline: isOnline(c.id),
      status: c.status,
    })));
  } catch (error) {
    console.error('[API] contacts error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Send a contact request.
app.post('/api/users/:id/contacts', auth.requireAuth, ensureSelf, async (req, res) => {
  const { id } = req.params;
  const { contact_id } = req.body || {};
  if (!contact_id) return res.status(400).json({ error: 'Missing contact_id' });
  if (id === contact_id) return res.status(400).json({ error: 'Cannot add yourself' });
  try {
    const target = await db.get('SELECT id FROM users WHERE id = ?', [contact_id]);
    if (!target) return res.status(404).json({ error: 'User not found' });
    await db.run(
      "INSERT OR IGNORE INTO contacts (user_id, contact_id, status) VALUES (?, ?, 'pending')",
      [id, contact_id]
    );
    sendToAccount(contact_id, { type: 'contact_request', from: id });
    res.json({ success: true, message: 'Contact request sent' });
  } catch (error) {
    console.error('[API] add contact error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Accept a contact request.
app.post('/api/users/:id/contacts/accept', auth.requireAuth, ensureSelf, async (req, res) => {
  const { id } = req.params;
  const { contact_id } = req.body || {};
  if (!contact_id) return res.status(400).json({ error: 'Missing contact_id' });
  try {
    await db.run(
      "UPDATE contacts SET status = 'accepted' WHERE user_id = ? AND contact_id = ?",
      [contact_id, id]
    );
    await db.run(
      "INSERT OR REPLACE INTO contacts (user_id, contact_id, status) VALUES (?, ?, 'accepted')",
      [id, contact_id]
    );
    sendToAccount(contact_id, { type: 'contact_accepted', from: id });
    res.json({ success: true, message: 'Contact request accepted' });
  } catch (error) {
    console.error('[API] accept contact error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Nearby users (same gym or within 200m), active in last 10 minutes.
app.get('/api/users/:id/nearby', auth.requireAuth, ensureSelf, async (req, res) => {
  const { id } = req.params;
  try {
    const user = await db.get('SELECT latitude, longitude, gym_id FROM users WHERE id = ?', [id]);
    if (!user) return res.status(404).json({ error: 'User not found' });
    const tenMinsAgo = Date.now() - 600000;
    const activeUsers = await db.query(
      'SELECT id, username, latitude, longitude, gym_id FROM users WHERE id != ? AND last_seen > ?',
      [id, tenMinsAgo]
    );
    const nearby = [];
    for (const u of activeUsers) {
      let reason = '';
      if (user.gym_id && u.gym_id && user.gym_id === u.gym_id) {
        reason = 'same_gym';
      } else if (user.latitude && user.longitude && u.latitude && u.longitude) {
        const dist = getDistance(user.latitude, user.longitude, u.latitude, u.longitude);
        if (dist <= 200) reason = `distance_${Math.round(dist)}m`;
      }
      if (reason) {
        const rel = await db.get(
          'SELECT status FROM contacts WHERE user_id = ? AND contact_id = ?',
          [id, u.id]
        );
        nearby.push({
          id: u.id,
          username: u.username,
          reason,
          isOnline: isOnline(u.id),
          relation: rel ? rel.status : 'none',
        });
      }
    }
    res.json(nearby);
  } catch (error) {
    console.error('[API] nearby error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Gyms (shared registry).
app.post('/api/gyms', auth.requireAuth, async (req, res) => {
  const { name, latitude, longitude, radius } = req.body || {};
  if (!name || latitude == null || longitude == null) {
    return res.status(400).json({ error: 'Missing name, latitude, or longitude' });
  }
  const id = `gym_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  try {
    await db.run(
      'INSERT INTO gym_locations (id, name, latitude, longitude, radius) VALUES (?, ?, ?, ?, ?)',
      [id, name, latitude, longitude, radius || 100.0]
    );
    res.json({ success: true, gym: { id, name, latitude, longitude, radius } });
  } catch (error) {
    console.error('[API] gym error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.get('/api/gyms', auth.requireAuth, async (_req, res) => {
  try {
    res.json(await db.query('SELECT * FROM gym_locations'));
  } catch (error) {
    console.error('[API] gyms error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Room discovery metadata (realtime membership is WS-authoritative).
app.get('/api/rooms', auth.requireAuth, async (_req, res) => {
  try {
    const list = await db.query('SELECT id, name, created_by, max_members FROM rooms');
    res.json(list.map((r) => ({
      id: r.id,
      name: r.name,
      createdBy: r.created_by,
      maxMembers: r.max_members,
      onlineMembers: rooms.has(r.id) ? rooms.get(r.id).size : 0,
    })));
  } catch (error) {
    console.error('[API] rooms error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.post('/api/rooms', auth.requireAuth, async (req, res) => {
  const { name, maxMembers } = req.body || {};
  if (!name) return res.status(400).json({ error: 'Missing name' });
  const id = `room_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  try {
    await db.run(
      'INSERT INTO rooms (id, name, created_by, created_at, max_members) VALUES (?, ?, ?, ?, ?)',
      [id, name, req.account.id, Date.now(), maxMembers || 10]
    );
    res.json({ room: { id, name, createdBy: req.account.id, maxMembers: maxMembers || 10 } });
  } catch (error) {
    console.error('[API] create room error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// ---------------------------------------------------------------------------
// WEBSOCKET SIGNALING & PRESENCE
// ---------------------------------------------------------------------------

const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });

  ws.on('message', async (messageText) => {
    let msg;
    try {
      msg = JSON.parse(messageText);
    } catch {
      return; // ignore non-JSON
    }

    const meta = sockets.get(ws);

    // Before authentication, only `register` is accepted.
    if (!meta && msg.type !== 'register') {
      return sendWS(ws, { type: 'error', message: 'Not authenticated' });
    }

    try {
      switch (msg.type) {
        case 'register': {
          const decoded = msg.token ? auth.verifyToken(msg.token) : null;
          if (!decoded) {
            sendWS(ws, { type: 'error', message: 'Invalid token' });
            return ws.close(4001, 'Invalid token');
          }
          registerSocket(ws, decoded.sub, decoded.dev);
          await db.run('UPDATE users SET last_seen = ? WHERE id = ?', [Date.now(), decoded.sub]);
          await db.run(
            'UPDATE account_devices SET last_seen = ? WHERE account_id = ? AND device_public_key = ?',
            [Date.now(), decoded.sub, decoded.dev]
          );
          sendWS(ws, { type: 'registered', status: 'ok', accountId: decoded.sub });
          notifyContactsStatus(decoded.sub, 'online');
          break;
        }

        // WebRTC signaling relay (account-addressed). Payload (SDP/ICE, signed
        // fingerprints) is opaque to the server.
        case 'signaling': {
          if (!msg.targetId) break;
          sendToAccount(msg.targetId, {
            type: 'signaling',
            from: meta.accountId,
            fromDevice: meta.device,
            payload: msg.payload,
          });
          break;
        }

        case 'call_request': {
          if (!msg.targetId) break;
          const delivered = sendToAccount(msg.targetId, {
            type: 'call_request',
            from: meta.accountId,
            fromDevice: meta.device,
            autoConnect: msg.autoConnect || false,
          });
          if (!delivered) sendWS(ws, { type: 'error', message: 'Target offline' });
          break;
        }

        case 'call_response': {
          if (!msg.targetId) break;
          sendToAccount(msg.targetId, {
            type: 'call_response',
            from: meta.accountId,
            fromDevice: meta.device,
            accepted: msg.accepted,
          });
          break;
        }

        case 'join_room': {
          const { roomId } = msg;
          if (!roomId) break;
          if (!rooms.has(roomId)) rooms.set(roomId, new Set());
          const room = rooms.get(roomId);
          room.add(meta.accountId);
          await db.run(
            'INSERT OR IGNORE INTO room_members (room_id, user_id, joined_at) VALUES (?, ?, ?)',
            [roomId, meta.accountId, Date.now()]
          );
          sendWS(ws, { type: 'room_joined', roomId, members: Array.from(room) });
          broadcastToRoom(roomId, meta.accountId, {
            type: 'room_member_joined',
            roomId,
            userId: meta.accountId,
            username: msg.username || null,
          });
          break;
        }

        case 'leave_room': {
          const { roomId } = msg;
          if (!roomId) break;
          const room = rooms.get(roomId);
          if (room) {
            room.delete(meta.accountId);
            await db.run('DELETE FROM room_members WHERE room_id = ? AND user_id = ?', [
              roomId,
              meta.accountId,
            ]);
            broadcastToRoom(roomId, meta.accountId, {
              type: 'room_member_left',
              roomId,
              userId: meta.accountId,
            });
            if (room.size === 0) rooms.delete(roomId);
          }
          sendWS(ws, { type: 'room_left', roomId });
          break;
        }

        case 'room_signaling': {
          const { roomId, targetId, payload } = msg;
          if (!roomId) break;
          const out = { type: 'room_signaling', roomId, from: meta.accountId, fromDevice: meta.device, payload };
          if (targetId) sendToAccount(targetId, out);
          else broadcastToRoom(roomId, meta.accountId, out);
          break;
        }

        case 'ping':
          sendWS(ws, { type: 'pong' });
          break;

        default:
          break;
      }
    } catch (err) {
      console.error('[WS] message error:', err);
    }
  });

  ws.on('error', (err) => console.error('[WS] socket error:', err.message));

  ws.on('close', () => {
    const meta = unregisterSocket(ws);
    if (meta && !isOnline(meta.accountId)) {
      removeFromAllRooms(meta.accountId);
      notifyContactsStatus(meta.accountId, 'offline');
    }
  });
});

// ws ping/pong keepalive — terminate sockets that stop responding.
const heartbeatInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) return ws.terminate();
    ws.isAlive = false;
    ws.ping();
  });
}, WS_HEARTBEAT_INTERVAL);
wss.on('close', () => clearInterval(heartbeatInterval));

// ---------------------------------------------------------------------------
// Graceful shutdown
// ---------------------------------------------------------------------------
function gracefulShutdown(signal) {
  console.log(`\n[Server] ${signal} received — shutting down gracefully...`);
  server.close(async () => {
    clearInterval(heartbeatInterval);
    wss.clients.forEach((ws) => ws.close(1001, 'Server shutting down'));
    try {
      await db.close();
      console.log('[Server] Database connection closed');
    } catch (err) {
      console.error('[Server] Error closing database:', err);
    }
    console.log('[Server] Shutdown complete');
    process.exit(0);
  });
  setTimeout(() => {
    console.error('[Server] Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
}
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------
server.listen(PORT, () => {
  console.log(`[Server] p2p-talk Signaling Server v${SERVER_VERSION} running on port ${PORT} (${NODE_ENV})`);
});

module.exports = { app, server };
