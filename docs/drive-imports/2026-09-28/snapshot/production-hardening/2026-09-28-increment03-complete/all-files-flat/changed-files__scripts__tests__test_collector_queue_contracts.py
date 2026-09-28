"""Actual SQLite schema/DML tests; not Android SQLiteOpenHelper or PostgreSQL acceptance."""
import ast
import hashlib
import importlib.util
from pathlib import Path
import re
import sqlite3
import tempfile
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "apps/momobio_sms_bridge/app"
SCHEMA = (APP / "src/main/assets/receipt_queue_v1.sql").read_text()
KOTLIN = (APP / "src/main/java/com/momobio/app/ReceiptQueueSql.kt").read_text()
DML = {name: ast.literal_eval(text) for name, text in re.findall(
    r'const val ([A-Z_]+) = ("[^\n]+")', KOTLIN)}


def key(value):
    return hashlib.sha256(str(value).encode()).hexdigest()


def put(db, ident, payload="synthetic", admitted=100):
    db.execute("INSERT INTO receipts(message_hash,payload,payload_bytes,received_at,admitted_at,state) VALUES (?,?,?,?,?,'pending')",
               (key(ident), payload, len(payload.encode()), admitted, admitted))


class NativeQueueSQLTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = str(Path(self.tmp.name) / "synthetic.db")
        self.db = sqlite3.connect(self.path, timeout=5)
        self.addCleanup(lambda: self.db.close())
        # Exercise the same statement delimiters used by QueueDatabase.onCreate.
        for block in SCHEMA.split("-- @statement"):
            sql = "\n".join(x for x in block.splitlines() if not x.strip().startswith("--")).strip()
            if sql:
                self.db.execute(sql)
        self.db.commit()

    def row(self, ident):
        return self.db.execute("SELECT state,payload,payload_bytes,acknowledged_at,reason FROM receipts WHERE message_hash=?", (key(ident),)).fetchone()

    def test_exact_statement_contract_is_present(self):
        self.assertEqual(set(DML), {"EXPIRE", "BATCH", "QUARANTINE", "ACKNOWLEDGE", "PRUNE_AGE", "PRUNE_ROWS"})
        self.assertEqual(self.db.execute("SELECT count(*) FROM sqlite_master WHERE type='trigger'").fetchone()[0], 1)

    def test_pending_receipt_survives_database_reopen(self):
        put(self.db, 1, "receipt 🚌\nsynthetic")
        self.db.commit(); self.db.close()
        self.db = sqlite3.connect(self.path)
        self.assertEqual(self.row(1)[0:2], ("pending", "receipt 🚌\nsynthetic"))

    def test_partial_acknowledgement_removes_only_acknowledged_raw_body(self):
        put(self.db, 1); put(self.db, 2)
        self.assertEqual(self.db.execute(DML["ACKNOWLEDGE"], (500, key(1))).rowcount, 1)
        self.assertEqual(self.row(1), ("acknowledged", None, 0, 500, None))
        self.assertEqual(self.row(2)[0], "pending")
        self.assertIsNotNone(self.row(2)[1])

    def test_unknown_or_repeated_ack_changes_no_rows(self):
        put(self.db, 1)
        self.assertEqual(self.db.execute(DML["ACKNOWLEDGE"], (500, key(999))).rowcount, 0)
        self.db.execute(DML["ACKNOWLEDGE"], (500, key(1)))
        self.assertEqual(self.db.execute(DML["ACKNOWLEDGE"], (600, key(1))).rowcount, 0)
        self.assertEqual(self.row(1)[3], 500)

    def test_duplicate_admission_cannot_resurrect_an_acknowledged_receipt(self):
        put(self.db, 1)
        self.db.execute(DML["ACKNOWLEDGE"], (500, key(1)))
        with self.assertRaises(sqlite3.IntegrityError):
            put(self.db, 1, "changed content")
        self.assertEqual(self.row(1)[0], "acknowledged")

    def test_policy_quarantine_retains_body_and_cannot_be_silently_acknowledged(self):
        put(self.db, 1)
        self.db.execute(DML["QUARANTINE"], ("policy_review", key(1)))
        self.assertEqual(self.db.execute(DML["ACKNOWLEDGE"], (500, key(1))).rowcount, 0)
        self.assertEqual(self.row(1)[0:2], ("quarantined", "synthetic"))
        self.assertEqual(self.row(1)[4], "policy_review")

    def test_pending_age_boundary_moves_to_review_not_deletion(self):
        put(self.db, 1, admitted=99); put(self.db, 2, admitted=100)
        self.db.execute(DML["EXPIRE"], (100,))
        self.assertEqual(self.row(1)[0], "quarantined")
        self.assertEqual(self.row(2)[0], "pending")
        self.assertEqual(self.row(1)[1], "synthetic")

    def test_failed_transaction_rolls_back_partial_acknowledgements(self):
        put(self.db, 1); put(self.db, 2); self.db.commit()
        with self.assertRaises(RuntimeError):
            with self.db:
                self.db.execute(DML["ACKNOWLEDGE"], (500, key(1)))
                raise RuntimeError("simulated local failure before commit")
        self.assertEqual(self.row(1)[0], "pending")
        self.assertEqual(self.row(2)[0], "pending")

    def test_batch_is_ordered_bounded_and_excludes_review(self):
        put(self.db, 1, admitted=10); put(self.db, 2, admitted=20); put(self.db, 3, admitted=30)
        self.db.execute(DML["QUARANTINE"], ("policy_review", key(1)))
        rows = self.db.execute(DML["BATCH"], (1,)).fetchall()
        self.assertEqual(rows, [(key(2), "synthetic")])

    def test_ack_retention_never_prunes_pending_or_quarantined(self):
        put(self.db, 1); put(self.db, 2); put(self.db, 3); put(self.db, 4)
        self.db.execute(DML["ACKNOWLEDGE"], (99, key(1)))
        self.db.execute(DML["ACKNOWLEDGE"], (100, key(2)))
        self.db.execute(DML["QUARANTINE"], ("policy_review", key(4)))
        self.db.execute(DML["PRUNE_AGE"], (100,))
        self.assertIsNone(self.row(1)); self.assertIsNotNone(self.row(2))
        self.assertEqual(self.row(3)[0], "pending"); self.assertEqual(self.row(4)[0], "quarantined")

    def test_ack_history_count_bound_prunes_only_oldest_ack_rows(self):
        for i in range(5):
            put(self.db, i)
            self.db.execute(DML["ACKNOWLEDGE"], (100+i, key(i)))
        put(self.db, 5)
        self.db.execute(DML["PRUNE_ROWS"], (2,))
        self.assertEqual(self.db.execute("SELECT count(*) FROM receipts").fetchone()[0], 3)
        self.assertIsNone(self.row(2)); self.assertIsNotNone(self.row(3)); self.assertIsNotNone(self.row(4))
        self.assertEqual(self.row(5)[0], "pending")

    def test_row_capacity_blocks_new_receipt_without_evicting_existing(self):
        for i in range(10000):
            put(self.db, i, "x")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "QUEUE_CAPACITY"):
            put(self.db, 10000, "x")
        self.assertEqual(self.db.execute("SELECT count(*) FROM receipts").fetchone()[0], 10000)
        self.assertEqual(self.row(0)[0], "pending")

    def test_byte_capacity_blocks_and_acknowledgement_releases_space(self):
        cap = 16 * 1024 * 1024
        size = 12 * 1024
        whole, rest = divmod(cap, size)
        for i in range(whole): put(self.db, i, "x" * size)
        put(self.db, whole, "x" * rest)
        with self.assertRaisesRegex(sqlite3.IntegrityError, "QUEUE_CAPACITY"):
            put(self.db, whole + 1, "x")
        self.db.execute(DML["ACKNOWLEDGE"], (500, key(0)))
        put(self.db, whole + 1, "x")
        self.assertEqual(self.row(whole+1)[0], "pending")

    def test_payload_metadata_and_state_constraints(self):
        put(self.db, 1, "🚌")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE receipts SET payload_bytes=1 WHERE message_hash=?", (key(1),))
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE receipts SET state='acknowledged' WHERE message_hash=?", (key(1),))
        with self.assertRaises(sqlite3.IntegrityError): put(self.db, 2, "x" * 12289)
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE receipts SET state='paid' WHERE message_hash=?", (key(1),))

    def test_two_real_sqlite_writers_preserve_unique_receipt(self):
        barrier = threading.Barrier(2)
        def writer():
            conn = sqlite3.connect(self.path, timeout=5)
            try:
                barrier.wait(timeout=5)
                with conn:
                    try: put(conn, 1); return "inserted"
                    except sqlite3.IntegrityError: return "duplicate"
            finally: conn.close()
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: writer(), range(2)))
        self.assertCountEqual(results, ["inserted", "duplicate"])
        self.assertEqual(self.db.execute("SELECT count(*) FROM receipts").fetchone()[0], 1)


spec = importlib.util.spec_from_file_location("certificate_verifier", ROOT / "apps/momobio_sms_bridge/scripts/verify_release_certificate.py")
CERT = importlib.util.module_from_spec(spec)
spec.loader.exec_module(CERT)


class CertificateParserTests(unittest.TestCase):
    def test_exact_release_certificate_is_accepted(self):
        CERT.verify("Signer #1 certificate SHA-256 digest: " + "a" * 64 + "\n", "a" * 64)
    def test_colon_delimited_fingerprint_is_supported(self):
        CERT.verify("Signer #1 certificate SHA-256 digest: " + "a" * 64 + "\n", ":".join(["AA"] * 32))
    def test_wrong_or_missing_certificate_is_rejected(self):
        for text in ["", "Signer #1 certificate SHA-256 digest: " + "b" * 64]:
            with self.assertRaises(ValueError): CERT.verify(text, "a" * 64)
    def test_multiple_signers_require_explicit_new_policy(self):
        text = "\n".join("Signer #"+str(i)+" certificate SHA-256 digest: "+"a"*64 for i in [1,2])
        with self.assertRaises(ValueError): CERT.verify(text, "a" * 64)
    def test_debug_dn_is_rejected_even_when_digest_matches(self):
        with self.assertRaises(ValueError):
            CERT.verify("Signer #1 certificate DN: CN=Android Debug, O=Android, C=US\nSigner #1 certificate SHA-256 digest: " + "a" * 64, "a" * 64)
    def test_invalid_expected_digest_is_rejected(self):
        for digest in ["", "a" * 63, "x" * 64]:
            with self.assertRaises(ValueError): CERT.verify("", digest)


if __name__ == "__main__":
    unittest.main()
