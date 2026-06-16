// ---------------------------------------------------------------------------
// test.js — end-to-end smoke test for the p2p-talk signaling server.
//
// Exercises the full account/keypair flow exactly as the Flutter client will:
//   register account -> enroll device subkey (identity-signed)
//   -> challenge/verify -> session JWT -> authenticated WS -> signaling relay.
//
// Uses Node's Ed25519 (raw 32-byte keys / 64-byte signatures), matching the
// `cryptography` Dart package on the client.
// ---------------------------------------------------------------------------

const crypto = require('crypto');
const http = require('http');
const WebSocket = require('ws');
const assert = require('assert');

const PORT = 3199;
process.env.PORT = PORT;
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret';
process.env.DB_PATH = ':memory:';
process.env.PUBLIC_HOST = 'turn.example.com';
process.env.TURN_SHARED_SECRET = 'test-turn-secret';

require('./server');

const BASE = `http://localhost:${PORT}`;

// --- helpers ---------------------------------------------------------------

function genKeyPair() {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
  const spki = publicKey.export({ format: 'der', type: 'spki' });
  const rawPub = spki.subarray(spki.length - 32); // last 32 bytes are the raw key
  return { publicKey, privateKey, rawPubB64: rawPub.toString('base64') };
}

function sign(privateKey, message) {
  const msg = Buffer.isBuffer(message) ? message : Buffer.from(message, 'utf8');
  return crypto.sign(null, msg, privateKey).toString('base64');
}

function post(path, body) {
  return request('POST', path, body);
}
function getJson(path, token) {
  return request('GET', path, null, token);
}

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const headers = { 'Content-Type': 'application/json' };
    if (data) headers['Content-Length'] = Buffer.byteLength(data);
    if (token) headers['Authorization'] = `Bearer ${token}`;
    const req = http.request(`${BASE}${path}`, { method, headers }, (res) => {
      let chunks = '';
      res.on('data', (c) => (chunks += c));
      res.on('end', () => {
        let parsed;
        try { parsed = JSON.parse(chunks); } catch { parsed = chunks; }
        resolve({ status: res.statusCode, body: parsed });
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

// Run the full enrollment + auth flow for one account, return its session token + id.
async function makeAccount(username) {
  const identity = genKeyPair();
  const device = genKeyPair();

  const reg = await post('/api/account/register', {
    username,
    identityPublicKey: identity.rawPubB64,
  });
  assert.strictEqual(reg.status, 200, `register ${username}: ${JSON.stringify(reg.body)}`);
  const accountId = reg.body.accountId;

  // Identity key authorizes the device key.
  const authorizationSig = sign(identity.privateKey, device.rawPubB64);
  const enroll = await post('/api/account/device', {
    accountId,
    devicePublicKey: device.rawPubB64,
    authorizationSig,
    deviceLabel: 'test-device',
  });
  assert.strictEqual(enroll.status, 200, `enroll: ${JSON.stringify(enroll.body)}`);

  // Challenge/response.
  const ch = await post('/api/auth/challenge', {
    accountId,
    devicePublicKey: device.rawPubB64,
  });
  assert.strictEqual(ch.status, 200, `challenge: ${JSON.stringify(ch.body)}`);
  const sig = sign(device.privateKey, ch.body.nonce);
  const ver = await post('/api/auth/verify', {
    accountId,
    devicePublicKey: device.rawPubB64,
    signature: sig,
  });
  assert.strictEqual(ver.status, 200, `verify: ${JSON.stringify(ver.body)}`);
  assert.ok(ver.body.token, 'token issued');

  return { accountId, token: ver.body.token, identity, device };
}

function connectWS(token) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${PORT}`);
    ws.on('open', () => ws.send(JSON.stringify({ type: 'register', token })));
    ws.on('message', (d) => {
      const msg = JSON.parse(d);
      if (msg.type === 'registered') resolve(ws);
    });
    ws.on('error', reject);
    setTimeout(() => reject(new Error('WS register timeout')), 4000);
  });
}

// --- tests -----------------------------------------------------------------

async function run() {
  let failures = 0;
  const check = async (name, fn) => {
    try { await fn(); console.log(`  ✓ ${name}`); }
    catch (e) { failures++; console.error(`  ✗ ${name}\n      ${e.message}`); }
  };

  console.log('\n--- p2p-talk server tests ---');

  await check('health endpoint', async () => {
    const r = await getJson('/health');
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.body.status, 'ok');
  });

  const alice = await makeAccount('alice_test');
  const bob = await makeAccount('bob_test');

  await check('full account+device+challenge flow issues a token', async () => {
    assert.ok(alice.token && bob.token);
  });

  await check('forged challenge signature is rejected', async () => {
    const ch = await post('/api/auth/challenge', {
      accountId: alice.accountId,
      devicePublicKey: alice.device.rawPubB64,
    });
    // Sign with the WRONG (identity) key instead of the device key.
    const badSig = sign(alice.identity.privateKey, ch.body.nonce + 'x');
    const ver = await post('/api/auth/verify', {
      accountId: alice.accountId,
      devicePublicKey: alice.device.rawPubB64,
      signature: badSig,
    });
    assert.strictEqual(ver.status, 401);
  });

  await check('device enrollment with bad authorization signature rejected', async () => {
    const id2 = genKeyPair();
    const dev2 = genKeyPair();
    const reg = await post('/api/account/register', {
      username: 'mallory_test',
      identityPublicKey: id2.rawPubB64,
    });
    // Sign device key with an unrelated key.
    const wrong = genKeyPair();
    const bad = sign(wrong.privateKey, dev2.rawPubB64);
    const enroll = await post('/api/account/device', {
      accountId: reg.body.accountId,
      devicePublicKey: dev2.rawPubB64,
      authorizationSig: bad,
    });
    assert.strictEqual(enroll.status, 401);
  });

  await check('protected route rejects missing token', async () => {
    const r = await getJson('/api/ice');
    assert.strictEqual(r.status, 401);
  });

  await check('/api/ice returns TURN creds (TLS-first) with valid token', async () => {
    const r = await getJson('/api/ice', alice.token);
    assert.strictEqual(r.status, 200);
    assert.ok(Array.isArray(r.body.iceServers));
    const urls = r.body.iceServers.flatMap((s) => (Array.isArray(s.urls) ? s.urls : [s.urls]));
    assert.ok(urls.some((u) => u.startsWith('turns:')), 'has turns: url');
    const turnEntry = r.body.iceServers.find((s) => String(s.urls).includes('turn'));
    assert.ok(turnEntry.username && turnEntry.credential, 'ephemeral creds present');
  });

  await check('username lookup works for contacts', async () => {
    const r = await getJson('/api/users/lookup?username=bob_test', alice.token);
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.body.id, bob.accountId);
  });

  await check('ensureSelf blocks acting as another account', async () => {
    const r = await request('GET', `/api/users/${bob.accountId}/contacts`, null, alice.token);
    assert.strictEqual(r.status, 403);
  });

  await check('unauthenticated WS register is closed', async () => {
    await new Promise((resolve) => {
      const ws = new WebSocket(`ws://localhost:${PORT}`);
      ws.on('open', () => ws.send(JSON.stringify({ type: 'register', token: 'garbage' })));
      ws.on('close', (code) => { assert.strictEqual(code, 4001); resolve(); });
      ws.on('error', () => resolve());
    });
  });

  await check('authenticated WS signaling relays between accounts', async () => {
    const aliceWs = await connectWS(alice.token);
    const bobWs = await connectWS(bob.token);
    const received = new Promise((resolve) => {
      bobWs.on('message', (d) => {
        const m = JSON.parse(d);
        if (m.type === 'signaling') resolve(m);
      });
    });
    aliceWs.send(JSON.stringify({ type: 'signaling', targetId: bob.accountId, payload: { sdp: 'x' } }));
    const m = await Promise.race([
      received,
      new Promise((_, rej) => setTimeout(() => rej(new Error('no relay')), 3000)),
    ]);
    assert.strictEqual(m.from, alice.accountId);
    aliceWs.close();
    bobWs.close();
  });

  await check('HTTP long-poll signaling relays between accounts', async () => {
    // Alice polls (registers as an HTTP client + waiter); Bob sends to Alice.
    const pollPromise = request('POST', '/api/rtc/poll', {}, alice.token);
    await new Promise((r) => setTimeout(r, 250));
    const send = await request('POST', '/api/rtc/send', {
      type: 'signaling', targetId: alice.accountId, payload: { sdp: 'http-relay-x' },
    }, bob.token);
    assert.strictEqual(send.status, 200, `send: ${JSON.stringify(send.body)}`);
    const poll = await Promise.race([
      pollPromise,
      new Promise((_, rej) => setTimeout(() => rej(new Error('poll timeout')), 5000)),
    ]);
    assert.strictEqual(poll.status, 200);
    const msgs = poll.body.messages || [];
    assert.ok(
      msgs.some((m) => m.type === 'signaling' && m.from === bob.accountId),
      `expected relayed signaling, got ${JSON.stringify(msgs)}`
    );
  });

  console.log(failures === 0 ? '\n--- ALL TESTS PASSED ---\n' : `\n--- ${failures} TEST(S) FAILED ---\n`);
  process.exit(failures === 0 ? 0 : 1);
}

setTimeout(run, 800);
