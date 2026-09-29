package com.momobio.app

/** Exact DML statements exercised by the portable SQLite contract suite. */
object ReceiptQueueSql {
    const val EXPIRE = "UPDATE receipts SET state='quarantined',reason='pending_age_review' WHERE state='pending' AND admitted_at < ?"
    const val BATCH = "SELECT message_hash,payload FROM receipts WHERE state='pending' ORDER BY admitted_at,message_hash LIMIT ?"
    const val QUARANTINE = "UPDATE receipts SET state='quarantined',reason=? WHERE message_hash=? AND state='pending'"
    const val ACKNOWLEDGE = "UPDATE receipts SET state='acknowledged',payload=NULL,payload_bytes=0,acknowledged_at=?,reason=NULL WHERE message_hash=? AND state='pending'"
    const val PRUNE_AGE = "DELETE FROM receipts WHERE state='acknowledged' AND acknowledged_at < ?"
    const val PRUNE_ROWS = "DELETE FROM receipts WHERE message_hash IN (SELECT message_hash FROM receipts WHERE state='acknowledged' ORDER BY acknowledged_at DESC,message_hash LIMIT -1 OFFSET ?)"
    const val OVERFLOW_HEAD = "SELECT message_hash,payload,payload_bytes,received_at,admitted_at FROM overflow_receipts ORDER BY admitted_at,message_hash LIMIT 1"
    const val OVERFLOW_DELETE = "DELETE FROM overflow_receipts WHERE message_hash=?"
}
