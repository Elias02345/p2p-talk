-- Migration 002 — per-device subkeys (ADDITIVE).
-- Applied idempotently by the server at boot (CREATE TABLE IF NOT EXISTS).

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
);
