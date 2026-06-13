# BioPay Reference Screen Gap Map

Date: 2026-06-12
Reference repo: `/Volumes/PRO-G40/BioPay`
Face enrollment UI reference repo: `/Volumes/PRO-G40/MEMORIES`
Target repo: `/Volumes/PRO-G40/MOBI/mobi_app`

## Boundary

The BioPay repo is a screen and interaction reference, not a payment authority
to copy into MOBI. MOBI payment remains a USSD dialer handoff. The payment is
completed outside the app by the telecom USSD flow. MOBI stores request,
dialer-opened, user-marked-paid, and externally-confirmed audit state only.

Face enrollment and face scan must use the AWS provider path. The Google ML Kit,
TFLite, MobileFaceNet, local-auth, and MoMo-credential parts of the reference
repo are historical context and must not become the restored production path.
The MEMORIES face capture interface is used only as a UI reference for camera
fit, face guide, and `Center`, `Turn`, `Hold` pose sequencing.

## Screen Mapping

| BioPay reference surface | MOBI fit | Restoration decision |
| --- | --- | --- |
| Splash/Auth | Existing MOBI app shell and auth | Do not add a separate BioPay auth app. |
| Home | `BioPay` bottom-tab action grid | Restored as QR, Scan, Face, and NFC. User activity page is removed as unsupported. |
| Profile | Existing profile plus BioPay enrollment state | Do not restore BioPay handle or MoMo credential editing as a standalone profile flow. |
| MoMo Setup | USSD recipient metadata only | Do not collect MoMo PINs, wallet secrets, or in-app payment credentials. |
| Face Enrollment | `/biopay/enroll` | Restored with camera capture and AWS enrollment/liveness provider. |
| Face Scan | `/biopay/face-scan` | Restored with camera capture, AWS match, then USSD request creation only on a matched provider face ID. |
| Confirm Match | Resolved payment preview in scan/face/NFC flows | Preserve confirm-before-dial behavior and hide the raw full USSD string from the screen. |
| Get QR Code | `/biopay/qr` | Restored with QR generation, `Generate QR Code`, and `Share QR Code`. |
| QR Scan | `/biopay/scan` | Restored with `MobileScanner`, safe token resolution, and external USSD dial action. |
| NFC | `/biopay/nfc` | Restored as `Activate NFC` then tap/hold near a BioPay NFC tag; no public read/write developer wording. |
| Admin Dashboard | `/admin/biopay` | Restored as BioPay Ops inside the MOBI admin shell. `/admin/finance` is a compatibility redirect only. |
| Admin Payees/Payee Detail | `/admin/biopay` Payees section | Restored with role-gated payee search/detail backed by Supabase RPCs. |
| Admin System Status | `/admin/biopay` Status section | Restored with AWS provider, database, USSD handoff, and audit readiness. |
| Admin Activity | Not supported in MOBI | Do not restore as a MOBI screen. External confirmation belongs in the BioPay Ops `Confirmations` section. |

## Reference Contracts Adopted

- QR card exposes `Share QR Code`, copies the same safe structured token payload
  used by the QR image, and avoids expiry-heavy UI copy.
- QR payloads carry the request token plus safe display metadata; they do not embed the raw USSD code.
- QR generation remains a payee/share surface; `Dial USSD` appears only after a
  payer resolves a QR/NFC/face request.
- QR, NFC, and face-scan request creation expose a compact RWF amount field
  before creating the external USSD request.
- NFC starts with `Activate NFC` and uses a `Tap to Pay` style surface instead
  of raw `Read Tag`/`Write Tag` controls.
- Confirm match launches the USSD string internally but does not display the raw
  full USSD code on screen.
- Face enrollment starts from `Start Enrollment` and moves into a camera flow
  with `Center`, `Turn`, `Hold` captures, an oval face guide, fitted front-camera
  preview, and AWS Rekognition enrollment.
- Face enrollment sends only the final selected frame for AWS indexing, while
  provider metadata records `enrollment_sample_count`, `enrollment_challenges`,
  `liveness_required`, and explicit `liveness_status`.
- Face scan starts with `Start Face Scan`, shows the camera guide, then uses
  `Match face`; a successful match creates a ready request but does not
  auto-open USSD before the user taps `Dial USSD`.
- Failed or unmatched face scan does not create a USSD payment request.

## Restored Admin Slice

The BioPay reference admin screens are restored in MOBI as one role-gated
operations console instead of a separate legacy app shell:

- `/admin/biopay` opens `BioPay Ops` for platform admins.
- `/admin/finance` remains a compatibility redirect for old admin links and should not be used in new UI copy.
- Summary metrics show payees, requests, pending external confirmations, and
  match rate.
- Payee list/search is backed by active `biopay_profiles` and profile display
  names.
- Payee detail shows enrollment status, AWS face subject, provider collection,
  liveness status, and request counts without exposing raw payment credentials.
- System status shows AWS provider readiness, database availability, external
  USSD handoff status, pending confirmations, and last audit event.
- Confirmations show request state and let an authorized admin mark
  `user_marked_paid` requests as externally confirmed after outside evidence is
  available.
