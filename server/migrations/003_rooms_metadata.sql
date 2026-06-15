-- Migration 003 — room discovery metadata (ADDITIVE).
-- Realtime room membership stays WebSocket-authoritative; these tables only
-- back discovery/metadata. Applied idempotently by the server at boot.

CREATE TABLE IF NOT EXISTS rooms (
  id TEXT PRIMARY KEY,
  name TEXT,
  created_by TEXT,
  created_at INTEGER,
  max_members INTEGER DEFAULT 10
);

CREATE TABLE IF NOT EXISTS room_members (
  room_id TEXT,
  user_id TEXT,
  joined_at INTEGER,
  PRIMARY KEY (room_id, user_id)
);
