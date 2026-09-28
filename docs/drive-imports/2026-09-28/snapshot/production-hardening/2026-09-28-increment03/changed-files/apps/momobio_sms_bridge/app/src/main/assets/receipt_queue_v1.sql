-- Shared schema used by Android SQLiteOpenHelper and isolated SQLite tests.
CREATE TABLE receipts (
  message_hash TEXT PRIMARY KEY NOT NULL,
  payload TEXT,
  payload_bytes INTEGER NOT NULL DEFAULT 0 CHECK (payload_bytes BETWEEN 0 AND 12288),
  received_at INTEGER NOT NULL,
  admitted_at INTEGER NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('pending','quarantined','acknowledged')),
  reason TEXT,
  acknowledged_at INTEGER,
  CHECK ((state = 'acknowledged' AND payload IS NULL AND payload_bytes = 0
          AND acknowledged_at IS NOT NULL) OR (state != 'acknowledged' AND payload IS NOT NULL AND payload_bytes = length(CAST(payload AS BLOB))))
);
-- @statement
CREATE INDEX receipts_ready ON receipts(state, admitted_at, message_hash);
-- @statement
CREATE TABLE queue_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
-- @statement
CREATE TRIGGER receipt_capacity_insert BEFORE INSERT ON receipts
WHEN NEW.state != 'acknowledged' AND (
 (SELECT count(*) FROM receipts WHERE state != 'acknowledged') >= 10000 OR
 (SELECT coalesce(sum(payload_bytes),0) FROM receipts) + NEW.payload_bytes > 16777216)
BEGIN SELECT RAISE(ABORT, 'QUEUE_CAPACITY_REVIEW_REQUIRED'); END;
