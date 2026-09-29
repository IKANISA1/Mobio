-- Additive upgrade from v1. Preserve all receipts and metadata in place.
CREATE TABLE overflow_receipts (
  message_hash TEXT PRIMARY KEY NOT NULL,
  payload TEXT NOT NULL,
  payload_bytes INTEGER NOT NULL CHECK (payload_bytes BETWEEN 1 AND 12288),
  received_at INTEGER NOT NULL,
  admitted_at INTEGER NOT NULL,
  CHECK (payload_bytes = length(CAST(payload AS BLOB)))
);
-- @statement
CREATE INDEX overflow_ready ON overflow_receipts(admitted_at, message_hash);
-- @statement
CREATE TRIGGER overflow_capacity_insert BEFORE INSERT ON overflow_receipts
WHEN (SELECT count(*) FROM overflow_receipts) >= 10000 OR
     (SELECT coalesce(sum(payload_bytes),0) FROM overflow_receipts) + NEW.payload_bytes > 16777216
BEGIN SELECT RAISE(ABORT, 'OVERFLOW_CAPACITY_REVIEW_REQUIRED'); END;
-- @statement
CREATE TABLE receipt_refusals (
  message_hash TEXT PRIMARY KEY NOT NULL,
  received_at INTEGER NOT NULL,
  first_refused_at INTEGER NOT NULL,
  last_refused_at INTEGER NOT NULL,
  attempts INTEGER NOT NULL CHECK (attempts >= 0),
  reason TEXT NOT NULL CHECK (reason IN ('capacity','oversize','invalid_hash')),
  recovered_at INTEGER
);
