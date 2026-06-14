# BioPay NFC Chip USSD Cards Report

Date: 2026-06-13
Status: Research and implementation recommendation
Scope: Add locked NFC cards/chips as another BioPay payment surface for MTN Rwanda MoMo USSD handoff.

## Executive Decision

The requested feature is technically feasible on Android in 2026, but the terminology and architecture need to be precise:

- The NFC card/chip is not a writer. It is a passive NFC tag with memory.
- The Android phone is the NFC reader/writer during card provisioning.
- Later, the same Android app can act as NFC reader to read the locked card and launch the USSD dialer flow.
- The card can be made read-only after provisioning, but this is a one-way operation. If the MoMo number or MoMo Pay code changes, that locked card must be replaced.

The best production path is to support two card types:

1. `BioPay NFC Static Merchant Card`:
   - Recommended for production.
   - Stores a Mobio/BioPay signed payload or app deep link, not raw USSD as the primary record.
   - The app reads the payload, validates it, builds the current USSD code, shows the receiver, and waits for `Dial USSD`.
   - This preserves the existing BioPay external-payment assistant contract.

2. `BioPay NFC Direct USSD Card`:
   - Feasible, but higher risk.
   - Stores the full USSD code, for example `*182*1*1*[momo number]#` or `*182*8*1*[momo pay code]#`, encoded as an NDEF URI or a signed application payload.
   - Should be restricted to explicit issuer/admin flows, because anyone who reads the tag can see/copy the destination code and the card cannot be corrected after locking.

For the physical chip/card, use NFC Forum Type 2 tags, preferably genuine NXP NTAG213 for the current USSD/deep-link payload size, or NTAG215 if future signed metadata, card IDs, environment labels, or issuer audit fields are expected. Avoid MIFARE Classic for broad Android compatibility.

## Current MOBI Fit

The current MOBI BioPay scope already allows QR, NFC, and face flows only as external-payment assistants. The app identifies a payee, amount, reference, and provider, then opens the phone USSD dialer. It must not capture MoMo PINs, wallet secrets, card data, or claim automatic settlement from the client alone.

Current app evidence:

- `android.permission.NFC` is already present in `android/app/src/main/AndroidManifest.xml`.
- NFC hardware is optional through `android.hardware.nfc required=false`, so non-NFC phones are not blocked from installing.
- `flutter_nfc_kit` and `ndef` are already dependencies.
- `BioPayNfcScreen` currently creates a BioPay NFC payment request, polls a tag, and writes a text NDEF record containing `buildBioPayQrPayload(request)`.
- The current payload intentionally contains a token/safe metadata, not raw USSD.
- The current NFC write path does not make the tag read-only after write.
- The app does not yet register Android NFC NDEF/deep-link intent filters for launching from a tapped passive tag while the app is closed.

This means the requested feature should be implemented as a dedicated provisioning screen, not by mutating the existing `NFC Tap` payment request screen. Suggested new routes:

- `/biopay/nfc` keeps the existing payment-request flow.
- `/biopay/nfc/write-card` provisions a new physical NFC card/chip.
- `/biopay/nfc/read-card` or background NDEF dispatch handles user taps on provisioned cards.

## Platform Capabilities In 2026

Android supports the required primitives:

- NDEF tag discovery and app dispatch. Android parses NFC tags, maps NDEF payloads to URI/MIME intents, and starts interested apps.
- Reader/writer mode. The app can poll NFC tags while the provisioning screen is foregrounded.
- NDEF writing. `Ndef.writeNdefMessage()` overwrites the NDEF message on compatible tags.
- Formatting blank tags. `NdefFormatable.format()` can format compatible unformatted tags as NDEF and write the first message.
- Locking. `Ndef.makeReadOnly()` and `NdefFormatable.formatReadOnly()` can make supported tags read-only. Android documents this as one-way and non-reversible.
- Flutter support. `flutter_nfc_kit 3.6.2` exposes NFC availability, polling, reading/writing NDEF records, raw transceive, and `makeNdefReadOnly()` for Android/iOS.

Key constraints:

- NFC I/O can fail if the tag leaves the RF field mid-write or mid-lock. The user must keep the phone still until success.
- Not every tag can be formatted or locked by every Android phone.
- Reader/writer operations must not run on the main Android UI thread in native code. The Flutter plugin handles the platform hop, but the UI still needs clear busy states and cancellation behavior.
- `ACTION_DIAL` is the safer USSD launch path because it opens the dialer and requires the user to press Call. Direct `sendUssdRequest()` exists but requires `CALL_PHONE`, requires telephony radio access, and bypasses the current UX boundary.
- A tag tap should not automatically initiate money movement. It should resolve the receiver and then expose `Dial USSD`, consistent with the approved BioPay scope.

## Recommended NFC Tag Hardware

### Best default: NXP NTAG213

Use for current direct USSD or token/deep-link cards.

Why:

- NFC Forum Type 2 compliant.
- ISO/IEC 14443 Type A.
- Broad smartphone compatibility.
- 144 bytes user memory, enough for a short `tel:` URI, app deep link, or compact signed token.
- Supports field-programmable read-only locking and password protection.
- Low cost and easy to buy as card, sticker, wristband, key fob, or embedded chip/inlay.

### Upgrade option: NXP NTAG215

Use if the payload will include signed metadata, card serial, merchant name, environment, version, issuer ID, and fallback URI.

Why:

- Same compatibility family as NTAG213.
- 504 bytes user memory.
- Gives enough space for multi-record NDEF messages and future audit/debug fields.

### High-capacity option: NXP NTAG216

Use only if the design requires larger offline payloads.

Why:

- 888 bytes user memory.
- More expensive and not needed for simple USSD cards.

### Avoid for this use case: MIFARE Classic

Avoid MIFARE Classic for new BioPay NFC cards. Android documentation recommends NFC Forum tag types for guaranteed compatibility and notes vendor NDEF formats do not work on all Android devices. MIFARE Classic also has device-chipset compatibility issues across Android hardware.

### Consider only for advanced secure cards: Type 4 tags

Type 4 tags such as DESFire-family cards are useful if future requirements include stronger card-side applications, access control, authentication, or secure file structures. They are not necessary for a simple locked static USSD or merchant-card flow and would raise cost and implementation complexity.

## Payload Design Options

### Option A: Signed BioPay payload or app link, recommended

Card records:

1. URI record:
   - `https://mobio.ikanisa.com/biopay/nfc?card=<card_id>` or `mobio://biopay/nfc?card=<card_id>`
2. External type record:
   - Domain: `rw.mobi.app`
   - Type: `biopay-card-v1`
   - Payload: compact JSON or CBOR:

```json
{
  "v": 1,
  "type": "momo_pay",
  "receiver": "123456",
  "country": "RW",
  "provider": "mtn_rw",
  "card_id": "BPNFC-...",
  "sig": "..."
}
```

3. Android Application Record:
   - Package: `rw.mobi.app`

Behavior:

- Tapping the card opens MOBI if installed.
- MOBI validates the payload signature or resolves `card_id`.
- MOBI builds the USSD string at runtime:
  - MoMo number: `*182*1*1*[number]#`
  - MoMo Pay merchant code: `*182*8*1*[merchant code]#`
- MOBI shows receiver details and `Dial USSD`.
- User confirms in the dialer and enters PIN inside telecom USSD only.

Pros:

- Safer than putting raw USSD as the first public record.
- Lets the app add anti-fraud checks, receiver display, audit, revocation, and future provider changes.
- Keeps current backend and status model intact.
- Supports offline fallback if the signed receiver is stored locally on the tag.

Cons:

- Needs app install for full experience.
- If only a backend card ID is stored, online resolution is required.

### Option B: Full USSD URI on card, feasible but controlled

Card records:

1. URI record:
   - `tel:*182*1*1*25078XXXXXXX%23`
   - `tel:*182*8*1*123456%23`
2. Android Application Record:
   - `rw.mobi.app`
3. Optional external app record:
   - Contains the same receiver data plus a card ID and signature for app validation.

Behavior:

- If MOBI handles the tag, it reads the USSD and shows `Dial USSD`.
- If another app/OS dialer handles `tel:`, the dialer may open directly with the USSD code.

Pros:

- Simple.
- Can work without backend resolution.
- Very small payload; NTAG213 is enough.

Cons:

- Anyone can read/copy the USSD destination.
- If the card is locked, it cannot be corrected.
- OS behavior for `tel:` USSD from NFC can vary by device/dialer.
- It can bypass the app’s token/resolution path if the phone chooses the dialer instead of MOBI.
- It conflicts with the existing BioPay product rule that QR/NFC payloads should not embed raw USSD unless that rule is explicitly amended for this new direct-card class.

If this option is approved, make it a separate card type with explicit UI copy like `Direct USSD card` and require issuer confirmation before permanent locking.

### Option C: Existing token-only NFC request, current behavior

Card records:

- Current text NDEF record with `buildBioPayQrPayload(request)`.

Pros:

- Already close to implemented.
- Uses current request status and backend resolver.

Cons:

- Current requests may expire.
- Not suited for permanent static cards unless the token points to a durable merchant profile rather than a payment request.
- Currently not locked.

### Option D: Android HCE, not the requested card flow

Android Host Card Emulation lets a phone emulate a card and talk to an NFC reader. This is useful for phone-to-terminal or phone-to-phone flows, but it does not create a passive physical card/chip that users can tap later. It should remain separate from the locked-card plan.

## Provisioning UX

Use a dedicated write-card screen.

Recommended flow:

1. User opens `BioPay > NFC > Write Card`.
2. User chooses receiver type:
   - `MoMo number`
   - `MoMo Pay code`
3. User enters the number/code.
4. App validates locally:
   - MoMo number: normalize to Rwanda canonical format already used elsewhere in the app.
   - MoMo Pay code: digits only, length policy configurable.
5. App shows a pre-lock confirmation:
   - Receiver type
   - Receiver value
   - USSD preview
   - Card type: `Signed BioPay card` or `Direct USSD card`
   - Warning that locking is permanent.
6. User taps `Write NFC`.
7. App shows a modal/bottom sheet: `Hold phone on new blank card`.
8. App polls NFC for 20-30 seconds.
9. App checks:
   - NFC available.
   - Tag is NDEF formatted or formatable.
   - Tag is writable.
   - Tag capacity is enough.
   - Tag is not already locked.
10. App writes the NDEF records.
11. App reads the tag back and validates bytes/records.
12. App locks the tag.
13. App reads again or checks `isWritable == false` when supported.
14. App shows final success:
   - `Card written and locked`
   - Receiver type/value
   - Card ID/tag UID if available
   - `Test tap` action.

Critical UX points:

- Do not lock before verifying the write.
- The final `lock` step must have a clear progress state because it cannot be undone.
- If write succeeds but lock fails, mark the card as `written_unlocked` and tell the issuer to retry lock or destroy/rewrite the card.
- If write fails mid-operation, do not trust the tag. Require a read/verify step or discard it.

## Reader UX For End Users

When an app user taps a written card:

1. Android dispatches the NDEF payload to MOBI using the app link, MIME/external record, or Android Application Record.
2. MOBI opens the BioPay card read/result screen.
3. MOBI displays:
   - Receiver type
   - Receiver label if known
   - USSD destination
   - Optional amount field if the card does not contain amount
4. User taps `Dial USSD`.
5. App opens the Android dialer with `tel:` URI.
6. User presses Call and completes MoMo PIN inside MTN USSD.
7. MOBI records `dialer_opened`.
8. User taps `I finished USSD`.
9. MOBI records `user_marked_paid`.
10. Only approved external/operator evidence moves the request to `confirmed`.

This should mirror QR scan and face scan behavior. The card tap should not auto-open USSD without a visible review screen.

## Locking Strategy

Use permanent read-only locking only after:

- payload is generated;
- NDEF write succeeds;
- read-back validation succeeds;
- issuer confirms the receiver is correct.

Android/native sequence:

1. `NfcAdapter.enableReaderMode()` or plugin polling while screen is foreground.
2. Get tag.
3. Try `Ndef.get(tag)`.
4. If NDEF exists:
   - connect;
   - check `isWritable`;
   - check `getMaxSize()`;
   - write NDEF;
   - read back;
   - call `makeReadOnly()` if `canMakeReadOnly()` is true.
5. If NDEF does not exist:
   - try `NdefFormatable.get(tag)`;
   - `formatReadOnly(message)` if supported, or `format(message)` then lock.
6. Always close tag technology session.

In Flutter today:

- `FlutterNfcKit.writeNDEFRecords(...)` can handle the write.
- `FlutterNfcKit.makeNdefReadOnly()` should be called after a successful write/read-back verification.
- For deeper native control, implement an Android platform channel in Kotlin using `Ndef`, `NdefFormatable`, `NdefRecord`, and `NdefMessage`.

For production reliability, I recommend moving card provisioning to a small native Android service/channel instead of relying only on the high-level plugin. The plugin is acceptable for MVP, but native code provides stronger control over `canMakeReadOnly()`, `getMaxSize()`, `formatReadOnly()`, read-back verification, technology-specific errors, and exact record composition.

## USSD Construction

Supported receiver types:

- MoMo number: `*182*1*1*[momo_number]#`
- MoMo Pay code: `*182*8*1*[momo_pay_code]#`

Encoding into a `tel:` URI:

- The final `#` must be URI-encoded as `%23`.
- Example:
  - Raw: `*182*8*1*123456#`
  - URI: `tel:*182*8*1*123456%23`

App behavior:

- Keep using `ACTION_DIAL`/external dialer style rather than `sendUssdRequest()` by default.
- Do not request `CALL_PHONE` unless a separately approved policy decision changes the BioPay boundary.
- Never collect the PIN or attempt to complete payment in-app.

## Security And Fraud Analysis

Main risks:

- Static card cloning: anyone can copy the NFC payload to another card.
- Receiver substitution during issuance: a user may accidentally or intentionally write the wrong number/code.
- Permanent lock mistake: once locked, the tag cannot be corrected.
- Offline payload staleness: if a merchant changes number/code, old cards keep pointing to the old receiver.
- Social engineering: a malicious tag could open a lookalike app link or direct USSD.
- App bypass: if the first NDEF record is a `tel:` URI, the system/dialer may handle the tag without MOBI.
- User confusion: NFC feels like contactless payment, but this is still USSD handoff requiring telecom PIN.

Required mitigations:

- Prefer signed BioPay payloads or app links as the first record.
- Keep direct raw USSD cards as a controlled/admin card type only.
- Show pre-lock confirmation with receiver and USSD preview.
- Require issuer confirmation before locking.
- Read back after write and after lock.
- Store issuance audit:
  - card ID
  - tag UID where available
  - receiver type
  - masked receiver value
  - issuer user ID
  - timestamp
  - app version/build
  - lock result
  - payload hash
- Do not trust tag UID for security. UIDs can be cloned on some tag families.
- Validate payload signature before acting on app-specific records.
- Keep user confirmation before opening USSD.
- If raw USSD is read from a card, parse and show it; do not silently launch.

## Backend Model

Add durable NFC card records separate from one-time payment requests.

Suggested table: `biopay_nfc_cards`

Fields:

- `id`
- `card_public_id`
- `tag_uid_hash`
- `owner_profile_id`
- `receiver_type`
- `receiver_value_hash`
- `receiver_value_encrypted` if server-side recovery is approved
- `provider_code`
- `payload_version`
- `payload_hash`
- `payload_signature_key_id`
- `status`: `draft`, `written`, `written_unlocked`, `locked`, `revoked`, `destroyed`
- `issued_by`
- `issued_at`
- `locked_at`
- `last_seen_at`
- `revoked_at`

Suggested RPCs:

- `rpc_create_biopay_nfc_card_payload`
- `rpc_record_biopay_nfc_card_written`
- `rpc_record_biopay_nfc_card_locked`
- `rpc_resolve_biopay_nfc_card`
- `rpc_revoke_biopay_nfc_card`

For direct raw-USSD cards, still store a card record and payload hash so support/admin can trace issued cards without storing unnecessary sensitive text in logs.

## Android Manifest And App Dispatch

To support tap-to-launch while the app is not already on the NFC screen, add one of these:

1. App link intent filter for HTTPS:
   - `https://mobio.ikanisa.com/biopay/nfc`
2. Custom scheme intent filter:
   - `mobio://biopay/nfc`
3. MIME or external NDEF filter:
   - `application/vnd.rw.mobi.biopay.nfc`
4. Android Application Record in the card message:
   - `rw.mobi.app`

Best combination:

- First record: HTTPS app link or external/MIME record specific to MOBI.
- Later record: Android Application Record.
- Avoid first record as `tel:` for production signed cards because it increases the chance of bypassing the app.

## Implementation Plan

### Phase 1: MVP write and lock

- Add `BioPayNfcWriteCardScreen`.
- Allow MoMo number or MoMo Pay code entry.
- Generate signed/static payload and optional direct-USSD URI.
- Write NDEF with `flutter_nfc_kit`.
- Call `makeNdefReadOnly()` after read-back verification.
- Record issuance audit locally/server-side.
- Add targeted widget/model tests for validation and USSD construction.
- Test on Pixel 4a with NTAG213 and NTAG215 cards.

### Phase 2: Native Android hardening

- Add Kotlin platform channel for:
  - capacity check;
  - `Ndef`/`NdefFormatable` branching;
  - exact `NdefRecord.createUri`, `createExternal`, `createMime`, `createApplicationRecord`;
  - `makeReadOnly`;
  - read-back verification;
  - precise error mapping.
- Add Android NDEF intent filters and route incoming NFC intents into Flutter.
- Add `Test tap` after issuance.

### Phase 3: Admin/ops

- Add admin card issuance list and revocation.
- Add issued-card status in BioPay Ops.
- Add CSV/export for physical card inventory.
- Add replacement flow for wrong/old locked cards.

### Phase 4: Field rollout

- Buy test batches from at least two suppliers.
- Test each physical format:
  - PVC card;
  - sticker;
  - key fob;
  - embedded chip/inlay.
- Test with multiple Android phones and dialers.
- Record failure rate for write, lock, read, and app dispatch.

## Acceptance Criteria

Provisioning:

- App detects no NFC / disabled NFC / unsupported device.
- App rejects invalid MoMo numbers and invalid MoMo Pay codes.
- App writes NTAG213 and NTAG215 test cards.
- App verifies written payload before locking.
- App locks supported cards.
- App confirms read-only state where the platform exposes it.
- App reports and stores partial states (`write_failed`, `written_unlocked`, `lock_failed`).

Reading:

- Tapping a provisioned card opens MOBI on Android when installed.
- Tapping a card with MOBI foregrounded resolves the card without app chooser.
- App shows receiver and `Dial USSD`.
- App opens dialer with encoded `tel:` URI and final `%23`.
- App records `dialer_opened` and `user_marked_paid`.
- App never records `confirmed` from client-only evidence.

Security:

- Direct-USSD card issuance requires explicit confirmation.
- No MoMo PIN or telecom secret is captured.
- NFC payloads are not logged raw.
- Issuance audit stores payload hash and masked receiver, not unnecessary raw secrets.
- Revoked signed cards are blocked by backend resolution.

Hardware:

- NTAG213 minimum pass rate is acceptable for write/read/lock.
- NTAG215 tested for expanded payloads.
- MIFARE Classic is excluded from supported card purchasing.

## Go/No-Go Recommendation

Go for an MVP if it is scoped as:

- Android-first;
- NTAG213/215 only;
- dedicated write-card screen;
- user-visible `Dial USSD`, not automatic payment;
- lock only after read-back verification;
- signed payload as default;
- direct raw USSD only as an explicitly approved card type.

No-go for production if the plan requires:

- automatic USSD execution without user review;
- capturing MoMo PIN;
- treating NFC card tap as confirmed payment;
- using MIFARE Classic as the standard card;
- locking cards before verifying payload;
- relying on raw tag UID as an anti-fraud control.

## Key Sources

- Android NFC basics and tag dispatch system: https://developer.android.com/develop/connectivity/nfc/nfc
- Android `Ndef` read/write/read-only API: https://developer.android.com/reference/android/nfc/tech/Ndef
- Android `NdefFormatable` format/read-only API: https://developer.android.com/reference/android/nfc/tech/NdefFormatable
- Android `NdefRecord` URI, external, MIME, and Android Application Record APIs: https://developer.android.com/reference/android/nfc/NdefRecord
- Android phone/dialer intents: https://developer.android.com/guide/components/intents-common
- Android `TelephonyManager.sendUssdRequest`: https://developer.android.com/reference/android/telephony/TelephonyManager
- Android host card emulation overview: https://developer.android.com/develop/connectivity/nfc/hce
- NFC Forum tag specifications overview: https://nfc-forum.org/build/specifications
- NXP NTAG213/215/216 product page: https://www.nxp.com/products/NTAG213_215_216
- NXP NTAG213/215/216 datasheet: https://www.nxp.com/docs/en/data-sheet/NTAG213_215_216.pdf
- Flutter NFC Kit package and API documentation: https://pub.dev/packages/flutter_nfc_kit and https://pub.dev/documentation/flutter_nfc_kit/latest/flutter_nfc_kit/FlutterNfcKit-class.html
- MTN Rwanda MoMo public information: https://www.mtn.co.rw/momo/
- MTN Rwanda MoMo Pay public information: https://www.mtn.co.rw/helppersonal/momo-pay/
