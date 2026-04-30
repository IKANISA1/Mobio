# Schema Inventory

## 1. MOBI Master Schema
- `profiles`: Extends auth.users. Includes role, name, phone, etc. Updated to use 6-digit `member_id` as the primary public identifier.
- `trips`: Core mobility data. Tracks requests, offers, locations, schedules.
- `countries`: Region configuration (RW is default). Expanded to include `sender_id` (from PayLedger `momo_providers`), `ussd_code_format`, and `currency`.
- `driver_locations`: Real-time driver tracking (PostGIS/geohash).
- `chat_conversations`, `chat_messages`: In-app P2P messaging.
- `ratings`: User review system.

## 2. PayLedger Schema (Migrated)
- `transactions`: Stores parsed financial transactions from SMS. Requires `agent_id` (mapped to MOBI `member_id`) and `sms_hash` for deduplication.
- `sms_raw_queue`: Raw audit trail of intercepted SMS for backend reconciliation.
- `momo_providers`: **MERGED** into MOBI `countries` table.

## 3. BioPay Schema (Migrated/Existing in MOBI via `biopay_schema.sql` and `biopay_face_foundation.sql`)
- `biopay_face_profiles`: Biometric profiles associated with users.
- `biopay_face_embeddings`: Stores 192D embeddings using `pgvector` for similarity matching.
- `biopay_installations`: Tracks device specific installations for security.
- `biopay_admin_actions`: Audit logs.

## 4. New Schema Required (Unified Payment Intent System - Phase 4)
- `payment_intents`: Core table bridging Trips and Payments.
- `payment_events`: State transitions for intents.
- `qr_payment_sessions`: Temp sessions for QR flow.
- `nfc_payment_sessions`: Temp sessions for NFC flow.
- `risk_flags`: Admin dispute and suspicious transaction tracking.
- `admin_audit_logs`: Replaces scattered admin logs.
