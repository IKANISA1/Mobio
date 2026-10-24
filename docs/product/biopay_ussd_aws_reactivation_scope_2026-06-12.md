# BioPay USSD And AWS Face Reactivation Scope

Date: 2026-06-12
Status: Approved implementation scope for recovery work

## Product Boundary

Mobio may restore BioPay, QR, NFC, face enrollment, and face scan only as an
external-payment assistant. The app identifies the payee, amount, reference, and
payment provider, then helps the user open the phone USSD dialer with a `tel:`
USSD code. The telecom USSD flow performs the payment outside Mobio.

Mobio must not collect or store MoMo PINs, card data, bank credentials, wallet
secrets, or telecom authentication secrets. Mobio must not claim automatic
settlement from the client alone. A user tap such as "Mark as paid" is only a
claim requiring confirmation through an approved external process.

## Active Features

- BioPay home command surface.
- QR payment request generation.
- QR scan resolution to a USSD dial action.
- NFC session resolution to a USSD dial action.
- Face enrollment with explicit biometric consent.
- Face scan resolving a registered payee and USSD dial action.
- RWF amount entry before QR, NFC, or face-scan request creation.
- Payment attempt and confirmation records for audit and operations.
- Role-gated BioPay Ops console for admin summary, payee directory, payee
  detail, system status, confirmations, and external confirmation.

## Payment Status Model

Payment request records use these statuses:

- `draft`
- `ready_to_dial`
- `dialer_opened`
- `user_marked_paid`
- `confirmed`
- `expired`
- `cancelled`
- `failed`

Only server-side operator, provider, or approved reconciliation evidence may
move a request to `confirmed`.
The app must not expose a public BioPay activity screen. `confirmed` is set only
through `rpc_confirm_biopay_ussd_external`, which requires the authenticated
payee and an external confirmation source.

## Face Provider

Production face enrollment and face scan must use the AWS provider abstraction
ported from the MEMORIES implementation:

- `FACE_PROVIDER=aws_rekognition`
- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REKOGNITION_COLLECTION_ID`

The old Google ML Kit and TFLite/MobileFaceNet implementation is historical
provider context and must not be restored as the production face authority.
Mobio's approved capture workflow keeps the front-camera preview, oval guide,
and `Center`, `Turn`, `Hold` sequence. Google ML Kit frame validation is not part
of the Mobio production path. These are product interaction requirements; their
visual treatment follows the external `revolut-design` skill.

AWS Rekognition responsibilities:

- Face Liveness session creation and result verification.
- Face enrollment through provider-side indexing.
- Face scan matching against the configured collection.
- Quality and duplicate checks before an enrollment is accepted.
- Successful enrollment persists AWS provider face and collection IDs through
  `rpc_record_biopay_face_enrollment`; raw selfie bytes are not database state.
- Face scan creates a USSD request only after AWS returns a matched provider
  face ID; the matched BioPay profile resolves the payee and USSD recipient.

## Product Presentation Requirements

The [external `revolut-design` skill](</Volumes/PRO-G40/Projects/ChatGPT/Revolut/skill/revolut-design/SKILL.md>)
is the sole design authority for Mobio app, web and admin. The restored BioPay
UI preserves these approved product actions and workflows:

- Bottom navigation includes `BioPay` as a first-class tab.
- BioPay home uses four icon-first action tiles: `QR`, `Scan`, `Face`, `NFC`.
- Admin BioPay uses `/admin/biopay` as a BioPay Ops console inside the current
  admin shell instead of restoring the old standalone BioPay admin app.
  `/admin/finance` is retained only as a compatibility redirect.
- QR generation is a payee/share surface and does not expose the payer-side
  dialer action.
- QR scan, NFC, and face scan result screens first use `Dial USSD`, then
  `I finished USSD` to record the user's external-payment claim.
- Face scan must not auto-open the USSD dialer immediately after an AWS match;
  it must show the resolved request and wait for the user to tap `Dial USSD`.
- QR, NFC, and face scan request screens use compact `Amount (RWF)` input
  controls instead of hidden fixed amounts.
- Screens avoid explanatory paragraphs and use compact status labels.
- Camera workflows are full-screen capture surfaces with minimal prompts:
  `Center`, `Turn`, `Hold`.
- Face enrollment capture submits AWS Rekognition enrollment after the guided
  capture sequence; raw selfie bytes are not stored as Mobio database state.
- Enrollment provider metadata records the guided sample count and challenge IDs
  (`straight_1`, `turn_pose`, `straight_2`) plus whether AWS liveness was
  required for that enrollment attempt.
- Error states provide retry/cancel without leaving a blank loading state.

## Backend Contract

Forward migrations must create new active BioPay tables instead of relying on
old dropped legacy payment tables. Required objects:

- `biopay_profiles`
- `biopay_payment_requests`
- `biopay_ussd_attempts`
- `biopay_face_sessions`
- `biopay_audit_events`

QR and NFC payload tables must not be publicly readable. Resolver RPCs may
return only safe metadata required to display the payee, amount, reference,
provider, and USSD code.

QR image payloads may include token, payee label, amount, currency, and
reference. They must not embed the raw USSD code; scan flows resolve the token
through the backend before opening the dialer.

Admin RPCs must require an authenticated `admin` profile and must not process
payment. They may list BioPay operational state and may move
`user_marked_paid` requests to `confirmed` only after external evidence is
available.

## Out Of Scope

- In-app wallet balances.
- Automatic in-app settlement.
- SMS inbox ingestion.
- MoMo PIN capture.
- Card or bank payments.
- Restoring local TFLite/MobileFaceNet assets as production identity authority.

## Acceptance Criteria

- Active routes exist for `/biopay`, `/biopay/qr`, `/biopay/scan`,
  `/biopay/face-scan`, `/biopay/enroll`, and `/biopay/nfc`.
- No public `/biopay/activity` route or activity page is exposed.
- BioPay UI exposes `Dial USSD`, not `Pay`, for money movement.
- User completion state is `user_marked_paid`; only external/operator evidence
  may set `confirmed`.
- Admin Confirmations list request status and exposes `Confirm external` only for
  externally reviewable `user_marked_paid` requests.
- Admin BioPay Ops exposes summary, payee directory/detail, system status, and
  confirmations through role-gated RPCs.
- BioPay Ops system status combines Supabase operational state with the AWS face
  provider edge-function health payload, including provider readiness and
  collection ID.
- Face scan must not create a payment request for `rejected` or empty AWS match
  results.
- Android and iOS camera permission copy refers to BioPay face enrollment/scan.
- Release tests assert USSD-only external payment and AWS provider boundaries.
- No active source depends on `google_mlkit_face_detection` or `tflite_flutter`
  for the restored production face path.
