# p2p-talk — Update Rules & Sacred Paths

This document defines the contract the auto-updater (`update.sh`) must honour.

## Sacred paths — NEVER modified or deleted by the updater

- `server/.env` — runtime secrets (backed up before every update, restored on rollback).
- `JWT_SECRET` and `TURN_SHARED_SECRET` (live inside `.env`).
- The SQLite database in the `p2ptalk_p2ptalk-data` Docker volume
  (`/app/data/p2ptalk.db` and its `-wal` / `-shm` siblings). Backed up before
  every update via a helper container; restored on rollback.
- `server/p2ptalk-release.jks` / `key.properties` are **app** signing material and
  are never present on the server.

## Update flow (enforced by `update.sh`)

1. **Check** — `git fetch`; compare local HEAD to `origin/<branch>`; stop if up to date.
2. **Backup** — copy `.env`, the pre-update commit hash, and a full DB copy to
   `/var/backups/p2ptalk/<timestamp>/`. **Abort the update if the backup fails.**
3. **Pull** — `git reset --hard origin/<branch>` (server truth = repo).
4. **Rebuild** — the systemd service rebuilds the Docker image with retry.
5. **Migrate** — additive only. The server self-applies schema deltas at boot
   (`db.js`: `ensureColumn`, `CREATE TABLE/INDEX IF NOT EXISTS`). See `migrations/`.
6. **Restart** — `systemctl restart p2ptalk-signaling`.
7. **Health check** — `curl http://127.0.0.1:<PORT>/health`. On failure → **rollback**.
8. **State** — write outcome to `/var/lib/p2ptalk/update-state/status.json`.

## Rollback (automatic on health-check failure)

Stop service → `git reset --hard <pre-update-commit>` → restore `.env` → restore DB →
restart → write `rolled-back` to the state file. A manual `revert-update.sh` also exists.

## Migration rules

- **Additive only**: new tables, new nullable columns, new indexes.
- Never `DROP`/`TRUNCATE`/unconditional `DELETE`.
- Must be idempotent (guarded with `IF NOT EXISTS` / `ensureColumn`).

## Channels

`UPDATE_BRANCH` in `.env` selects the train (`main` = stable, `dev` = pre-release).
The app can switch trains by calling `update.sh --branch <train>`.
