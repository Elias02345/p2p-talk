-- Migration 001 — account identity model (ADDITIVE).
-- The server applies these idempotently at boot (db.js: ensureColumn +
-- CREATE INDEX IF NOT EXISTS), so no manual run is required. This file is the
-- authoritative record of the schema delta for the update contract.

ALTER TABLE users ADD COLUMN identity_public_key TEXT;
ALTER TABLE users ADD COLUMN created_at INTEGER;
ALTER TABLE users ADD COLUMN settings_json TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_identity ON users(identity_public_key);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
