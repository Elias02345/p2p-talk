const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Resolve DB path from environment variable or default to local file.
// This file (and its -wal/-shm siblings) is a SACRED PATH — see docs/UPDATE_RULES.md.
// ':memory:' is passed through unresolved (used by the test harness).
const dbPath = process.env.DB_PATH
  ? (process.env.DB_PATH === ':memory:' ? ':memory:' : path.resolve(process.env.DB_PATH))
  : path.join(__dirname, 'p2ptalk.db');

const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Failed to connect to SQLite database:', err);
  } else {
    console.log('Connected to SQLite database at', dbPath);
    initializeDatabase();
  }
});

/** Execute a SELECT query and return all matching rows. */
function query(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => (err ? reject(err) : resolve(rows)));
  });
}

/** Execute an INSERT/UPDATE/DELETE. Resolves with { id, changes }. */
function run(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve({ id: this.lastID, changes: this.changes });
    });
  });
}

/** Execute a SELECT query and return the first matching row (or undefined). */
function get(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => (err ? reject(err) : resolve(row)));
  });
}

/** Close the database connection gracefully. */
function close() {
  return new Promise((resolve, reject) => {
    db.close((err) => (err ? reject(err) : resolve()));
  });
}

/**
 * Idempotently add a column to a table if it does not already exist.
 * Used for additive-only migrations (existing installs must survive in place).
 */
async function ensureColumn(table, column, ddl) {
  const cols = await query(`PRAGMA table_info(${table})`);
  if (!cols.some((c) => c.name === column)) {
    await run(`ALTER TABLE ${table} ADD COLUMN ${ddl}`);
    console.log(`[DB] Added column ${table}.${column}`);
  }
}

async function initializeDatabase() {
  try {
    // Accounts. `users.id` is the accountId (derived from the identity public
    // key). Kept named `users` so existing contact/room foreign keys still work;
    // existing single-device UUIDs are valid account ids.
    await run(`
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        last_seen INTEGER NOT NULL,
        gym_id TEXT,
        latitude REAL,
        longitude REAL
      )
    `);

    // Additive columns introduced with the account/keypair model.
    await ensureColumn('users', 'identity_public_key', 'identity_public_key TEXT');
    await ensureColumn('users', 'created_at', 'created_at INTEGER');
    await ensureColumn('users', 'settings_json', 'settings_json TEXT');

    // Unique identity key (one account per identity) and username lookup.
    await run('CREATE UNIQUE INDEX IF NOT EXISTS idx_users_identity ON users(identity_public_key)');
    await run('CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)');

    // Authorized device subkeys per account.
    await run(`
      CREATE TABLE IF NOT EXISTS account_devices (
        account_id TEXT NOT NULL,
        device_public_key TEXT NOT NULL,
        authorization_sig TEXT NOT NULL,
        device_label TEXT,
        created_at INTEGER NOT NULL,
        last_seen INTEGER,
        revoked INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (account_id, device_public_key),
        FOREIGN KEY (account_id) REFERENCES users(id) ON DELETE CASCADE
      )
    `);

    await run(`
      CREATE TABLE IF NOT EXISTS contacts (
        user_id TEXT,
        contact_id TEXT,
        status TEXT NOT NULL, -- 'pending', 'accepted'
        PRIMARY KEY (user_id, contact_id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (contact_id) REFERENCES users(id) ON DELETE CASCADE
      )
    `);

    await run(`
      CREATE TABLE IF NOT EXISTS gym_locations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius REAL NOT NULL DEFAULT 100.0
      )
    `);

    // Room metadata (discovery). Realtime room membership is WS-authoritative.
    await run(`
      CREATE TABLE IF NOT EXISTS rooms (
        id TEXT PRIMARY KEY,
        name TEXT,
        created_by TEXT,
        created_at INTEGER,
        max_members INTEGER DEFAULT 10
      )
    `);

    await run(`
      CREATE TABLE IF NOT EXISTS room_members (
        room_id TEXT,
        user_id TEXT,
        joined_at INTEGER,
        PRIMARY KEY (room_id, user_id)
      )
    `);

    console.log('Database tables initialized successfully.');
  } catch (error) {
    console.error('Error initializing database tables:', error);
  }
}

module.exports = { db, query, run, get, close, ensureColumn };
