# M063 typed boundary and M006 member ID audit

Date: 2026-09-30

Scope: active Flutter person, scheduled-trip, member-ID, wallet, chat,
notification, admin and approved BioPay USSD response contracts. Public transport
and payment-discovery changes are coordinated with the same local remediation
program. This report records source contracts and local tests; deployed SQL,
provider operation and physical-device acceptance require their own evidence.

## Implemented rules

- Validate required identities, exact integer amounts/counts, declared states,
  timestamps, row containers and response correlation before constructing UI
  models. A malformed list cannot become an empty successful result or silently
  lose a row.
- Preserve explicit zero counts and the nullable fields declared by SQL.
  Unknown required state cannot become `active`, `ready_to_dial`, `completed`,
  `ok`, or a fabricated current timestamp.
- Keep direct preview/display constructors available. Permissive shared
  presentation factories are reached through a strict data-boundary validator
  when they consume server responses.
- An acknowledged mutation whose receipt is malformed or mismatched has an
  unknown outcome. Preserve the original operation identity and recovery
  pointer; do not fabricate success or automatically create another operation.
- Revalidate the captured account/session generation after private asynchronous
  work. A response or rendered callback for an earlier generation cannot publish
  private data or navigate using an old notification.

## Coverage matrix

| Boundary | Implemented validation and correlation | Source |
| --- | --- | --- |
| Own and public profile | UUID identity, expected requested identity, role, explicit driver flag and exact six-digit member ID when available; a public-profile query must return zero or exactly one row | `lib/features/profile/domain/profile_wire_record.dart`; `lib/features/profile/data/profile_service.dart` |
| Nearby discovery person | Driver UUID, exact raw six-digit member ID, nonempty vehicle type, finite/ranged coordinates and nonnegative distance; explicit nonnegative discovery counts | `lib/features/nearby/data/driver_location_service.dart` |
| Home/Nearby person cards | Dedicated `DiscoveryPerson` peer identity and chat URI; live discovery no longer invents scheduled-trip identities or dates | `lib/shared/models/discovery_person.dart`; `lib/shared/widgets/driver_card.dart`; Home/Nearby presentation |
| Full scheduled-trip rows | Trip and author UUIDs, labels, calendar departure date, role, vehicle type, declared status, explicit active/recurrence flags, unique integer weekday indices 0–6, valid skip/end dates and optional finite/ranged coordinates | `lib/features/bookings/domain/trip_wire_record.dart` |
| Scheduled-trip reads and writes | Detail ID matches the requested ID; own-list rows match the captured author; create/update UUID acknowledgements and fetched owner/ID are correlated; malformed post-write results are unknown | `lib/features/bookings/data/trip_service.dart` |
| Pool occurrence projection | Validates the SQL occurrence projection (`trip_id`, score and reason); its SQL-selected active occurrence is represented explicitly without pretending the response includes the original recurrence definition | `TripWireRecord.parsePoolOccurrence` |
| Wallet summary and ledger | Owner correlation, exact nonnegative counters, positive ledger amounts, required ledger UUID/direction/reason/time; explicit empty ledger remains valid | `lib/features/profile/domain/wallet.dart`; `lib/features/profile/data/wallet_service.dart` |
| Wallet recipient and receipts | Lookup must be one JSON object with exactly the requested six-digit member ID and explicit display name; required transfer/redemption IDs, declared state and positive exact amounts | `WalletTransferRecipient`, `WalletTransferReceipt`, `WalletRedemptionReceipt` |
| Wallet operation journal | Captured owner, operation/kind/amount/receiver correlation; committed financial receipt validated before use; execution and close malformed acknowledgements remain unknown; durable pointer is retained | `WalletService`; existing `WalletOperationRecord` and journal |
| Referral and subscription response models | Explicit code/identity/state/amount/flags/times, positive exact payment amounts, optional subscription UUID and nullable USSD value; absent driver status cannot inherit eligibility defaults | `lib/features/profile/domain/wallet.dart`; Driver Plus/referral data services |
| Admin users and scheduled posts | Required UUID identities, role/type/status/flags/time; member-ID field retains supported nullable legacy values without generating an ID | `lib/features/admin/domain/admin_wire_record.dart`; admin user/trip services |
| Admin dashboard, token credits and settings | Required exact counts including valid zero; token receipt owner+amount+completed state; explicit setting values and normalized-value acknowledgement | `AdminWireRecord.dashboard`, `tokenAdjustment`, `platformSettings`; admin user/dashboard services |
| Admin WhatsApp and redemption operations | Required row shape and valid phone/member IDs; exactly one returned row for WhatsApp writes; ID/phone/country/active or redemption ID/status correlation; malformed write acknowledgement is unknown | admin dashboard/user services and `AdminWireRecord` |
| Admin compliance | Audit identity/action/target/details/time, report reporter/reported identities and declared states, operational-health declared status/severity/origin; deleted/nullable actors and subjects retained | admin compliance service and `AdminWireRecord` |
| Admin broadcast | Campaign identity/organization/requester/state/counts/times, consent summary/trend counts, audience and timeline campaign correlation; malformed campaign ID or sent-recipient count is unknown | admin broadcast service and `AdminWireRecord` |
| Chat conversation and history | UUID identities, distinct participants, requested owner/conversation/trip/peer correlation, explicit context/state/preview/times; full message type/body/metadata/time required; keyset order and exact cursor timestamps retained | `lib/features/chat/domain/chat_wire_record.dart`, conversation/message/history models; chat service |
| Chat durable send/close | Owner, conversation, client-message UUID and exact body digest correlation; malformed acknowledged send/close receipt is unknown and preserves the pointer; an already valid sent receipt remains authoritative if later close/local cleanup fails | chat delivery coordinator and existing delivery models |
| Inbox notification data | Required IDs/type/title/metadata/read/visibility/time, nullable body, owner correlation for private inbox/unread/realtime; list predicates are validated; exactly one matching mark-read acknowledgement | `lib/features/notifications/data/notification_service.dart` |
| Inbox notification callbacks | Account listener clears cached rows with a fresh FutureBuilder key; rows and toolbar callbacks retain the rendered ticket; late writes cannot navigate/refresh the next generation; load futures and bounded subscription cleanup are observed | notification screen and notification service |
| BioPay USSD request/activity | Required UUID, opaque token, channel, provider/payee, exact amount, currency/reference/USSD, declared status and times; confirmed state requires external confirmation metadata | `lib/features/biopay/domain/biopay_ussd_payment.dart` |
| BioPay USSD writes | Immutable instruction identity is correlated; SQL resulting state is required: create `ready_to_dial`, dialer `dialer_opened`, mark `user_marked_paid`, external confirmation `confirmed` with the submitted trimmed source | `lib/features/biopay/data/biopay_ussd_service.dart` |
| BioPay resolve projection | Separate parser matches the declared token and resolving states; absent creation/confirmation fields are retained as unavailable rather than synthesized | `BioPayUssdPaymentRequest.fromResolvedJson` |
| BioPay admin | Required payee identity/state/counts and nullable legacy provider fields; exact summary counts and finite rate; explicit system-readiness flags/states; external confirmation instruction/source correlation | `lib/features/biopay/domain/biopay_admin.dart`; admin service |

The public-transport boundary is implemented in
`lib/features/bookings/domain/public_transport_wire_record.dart` and its data
service: agencies, schedule projections, holds, booking/payment states,
amounts/counts/times and requested booking correlation. Root-owned payment
discovery uses explicit workspace/link/admin projections plus strict draft,
quote, prepared-instruction and successful mutation response parsing. Their
focused and integrated outcomes are recorded by the aggregate verification run.

The EV priority check confirms that `rpc_find_nearest_ev_chargers` declares
`is_active` in its return shape. A direct table list may omit `distance_km`, which
is therefore intentionally nullable. EV UUID and upsert acknowledgement
validation are included in the root-owned remediation; set-active returns SQL
`void` and does not require an invented result row.

## Final M006/M063 requirement cross-check

| Requirement | Current source rule | Local regression evidence |
| --- | --- | --- |
| M006: one canonical member ID across supported projections | Profile, Nearby/DiscoveryPerson, joined admin scheduled trip, chat peer and wallet recipient retain `004321`; UUIDs remain separate internal identities | `test/shared/models/member_id_boundary_parity_test.dart` checks all five projections and actual discovery/chat rendering; `test/shared/widgets/driver_person_card_test.dart` checks the person card and callback |
| M006: unavailable or ambiguous identity cannot authorize a recipient | Profile/admin nullable IDs stay unavailable; wallet lookup requires one object with the exact requested six-digit ID | `test/features/profile/data/wallet_service_boundary_test.dart` covers missing, wrong and ambiguous responses for `004321`; parity test covers nullable profile/admin IDs |
| M063: people and scheduled trips have distinct contracts | Home/Nearby live cards use `DiscoveryPerson` and peer chat URIs; scheduled cards retain actual `Trip` IDs and their own navigation | Home/Nearby person source, `member_id_boundary_parity_test.dart`, `driver_person_card_test.dart` and `test/app/router/return_navigation_test.dart` |
| M063: new-method acknowledgement matches persisted input | New rows require version 1 and active state; existing rows require the same ID and the next version; label/identifier use SQL trim and empty login/SIM values use SQL null normalization | `test/features/biopay/data/payment_discovery_receipt_test.dart` has complete new-row success plus wrong version/label/SIM/active negative cases |
| M063: evidence belongs to the requested action | `acknowledge` accepts only receiver/operator/provider evidence; `record_attempt` accepts the submitted result or explicitly preserved stronger evidence | Receipt test rejects an unrelated action result and retains valid provider-confirmed evidence; controller tests validate quote/prepare/action contracts before publishing |
| M063: links, templates and pay-again drafts have correlated receipts | A new link matches its submitted fields and expiry instant, version 1 and no revocation; a template retains exact nested data; pay-again returns revision 0, draft evidence and no previous attempt | Receipt test includes complete SQL-compatible positive link/template/pay-again cases, nested-object key-order compatibility and field/state mismatch failures |
| M063: historical money remains exact | Workspace history retains the integer minor amount and explicit currency; `formatHistoricalAmountMinor` renders the fraction without floating point or truncation. New discovery preparation still requires whole RWF | Receipt test preserves `150050`, rendering `1500.50 RWF` and `1500.50 USD`; `test/features/biopay/payment_library_workspace_boundary_test.dart` checks both actual rendered values |
| M063: injected service responses cannot bypass workspace validation | Composer, library and request-editor loads revalidate the full workspace with their captured owner before publishing. Unavailable data does not render private input, an empty-history claim or an add-method prompt | Workspace widget tests reject missing sections, missing currency and another owner before publication; corrected complete responses remain usable |
| M063: admin route acknowledgements match the SQL transition | Save and disable advance the adapter version; tested/approve preserve it. New routes start both versions at 1, save retains normalized configuration and clears review fields, and timestamps compare as instants | `test/features/biopay/data/payment_route_receipt_test.dart` covers complete new/existing rows, valid timestamp normalization, transition versions, changed configuration and unknown malformed-success outcomes |

The five earlier discovery receipt review findings are corrected in current
source: historical minor/currency preservation, new-method correlation,
action-specific evidence, exact link/template values and fresh pay-again state.
The library consumes the same validated contract even when a service is
overridden. Synthetic shared fixtures now include the owner, reference and
timestamp fields present in the SQL projections; production parsers do not
invent these values.

## Authoritative SQL shapes and preserved nullable values

The contracts were compared with the local forward migration history,
including:

- `20260929215433_mobio_hardening_canonical_member_id.sql`: canonical member IDs
  remain six numeric characters; leading zeroes are meaningful. Lookup returns
  one JSON recipient object.
- `20260929215435_mobio_hardening_bounded_driver_discovery.sql`: nearby discovery
  and aggregate-count projections.
- `20260613143000_scheduling_rpc_production_hardening.sql`: scheduled-trip
  creation/edit and occurrence projection. The occurrence projection does not
  contain a full recurrence definition.
- `20260614120000_wallet_referrals_driver_plus.sql`,
  `20260616110000_wallet_redemptions_and_insurance_config.sql`, and
  `20260929215439_mobio_hardening_wallet_operation_journal.sql`: wallet ownership,
  counters, financial receipts and durable operation states.
- `20260501090000_tenant_permissions_storage_realtime_hardening.sql`,
  `20260501135000_scope_cleanup_scheduled_trip_post_status.sql`, and
  `20260615123000_admin_trip_search_pagination.sql`: admin row projections and
  normalization.
- `20260501070000_admin_audit_finance_review_contracts.sql`,
  `20260501132000_admin_revocation_and_operational_events.sql`, and
  `20260501133000_user_reports_blocks.sql`: audit, health and report contracts.
- `20260501125000_campaign_search_consent_analytics.sql`,
  `20260501130000_campaign_detail_preview_hardening.sql`, and
  `20260501131000_campaign_audit_timeline_lint_fix.sql`: campaign, audience,
  consent/trend and timeline projections.
- `20260327113000_in_app_chat_foundation.sql`,
  `20260614173000_restore_chat_block_enforcement.sql`, and
  `20260929215440_mobio_hardening_chat_delivery_and_pagination.sql`: conversation,
  message, exact cursor and durable delivery contracts.
- `20260327203000_notifications_and_admin_access_alerts.sql` and later
  notification visibility changes: explicit notification delivery/read fields.
- `20260612133000_biopay_ussd_aws_reactivation.sql`,
  `20260612143000_biopay_qr_optional_amount.sql`,
  `20260612204806_profile_momo_receiver_fields.sql`, and
  `20260615135000_biopay_payment_request_links.sql`: full USSD rows, approved
  zero/open amount, declared resolve projection and action states.
- `20260906143000_biopay_provider_authority.sql`,
  `20260920150000_biopay_face_shortcut.sql`, and
  `20260920150100_biopay_face_readiness.sql`: admin payee and readiness states.
- `20260908090000_biopay_payment_discovery.sql`,
  `20260908092000_biopay_discovery_admin.sql`, and the current discovery RPC in
  `20260920150100_biopay_face_readiness.sql`: workspace/receiving projections,
  saved-method normalization, nested draft preservation, quote/prepare results,
  evidence transitions, link/template receipts and fresh pay-again state.
- `20260615133000_ev_charger_locator.sql`: charger IDs, activation/distance
  projection, UUID upsert acknowledgement and void set-active result.

Nullable values preserved include optional coordinates and recurrence end
date, legacy/public profile member-ID absence, referral links, replay transfer
ledger IDs, redemption MoMo number, subscription UUID/USSD, deleted admin actor
or target, optional report reviewer/conversation/trip, approval actors/times,
system-message sender/read time, notification body and legacy BioPay provider
subject/collection fields.

Chat delivery `message_id` is nullable with `ON DELETE SET NULL`. A historical
`sent` operation whose message was later deleted is still a valid sent
operation; its operation/owner/conversation/digest/state remain checked. The
minimal `not_observed` status projection legitimately omits receipt fields.

## M006 cross-boundary member ID evidence

`test/shared/models/member_id_boundary_parity_test.dart` uses one server subject
with canonical ID `004321` across:

1. `ProfileWireRecord` for the subject profile.
2. `NearbyDriver` and `DiscoveryPerson` for nearby discovery.
3. `AdminWireRecord.trip` for the joined scheduled-trip admin projection.
4. The chat peer profile and the actual `ConversationList` formatter.
5. `WalletTransferRecipient` for the exact requested transfer recipient.

The shared parity test verifies the same internal subject UUID independently
from the display member ID. The actual discovery and chat widgets render
`004321` / `Member 004321` without rendering the internal subject or trip UUID.
The ordinary public `Trip` model has `author_id` and `author_name`, not a
`member_id` field; the test does not claim a projection that SQL does not return.

Source inspection confirms that the own-profile formatter uses
`displayMobioMemberId` and renders an unavailable state when no valid member ID
exists. Chat uses the same formatter; wallet confirmation uses the exact
server-returned ID. Active feature code has no `getDriverId` or generated/hash
member-ID fallback. Remaining trip `hashCode` uses are widget/place keys, not
member identity. Nearby RPC rows reject whitespace around a purported raw ID.

Missing/wrong/ambiguous wallet recipients are tested before confirmation.
Supported nullable profile/admin membership never creates a synthetic ID.
These are local model/widget checks, not rendered-device or deployed-database
parity acceptance.

## Negative and compatibility regressions

- Missing, wrong or malformed required identity, role, flag, state, date,
  container, count and amount fields reject the complete response.
- Wrong owners and requested entity IDs are rejected; private results are
  discarded after account-generation changes.
- Fractional, string, negative or oversized integer amounts/counts are rejected;
  explicit valid zero counts remain valid.
- Invalid recurrence indices, duplicate weekdays, impossible calendar dates and
  nonfinite/out-of-range coordinates reject trip rows.
- Empty committed wallet receipts, wrong redemption amounts and malformed
  execution/close acknowledgements cannot confirm success; the durable operation
  pointer survives.
- Trip create/edit malformed IDs, returned-owner substitution and detail/own-list
  correlation failures are covered.
- Admin token, WhatsApp, settings, redemption, campaign and send-count malformed
  acknowledgements cannot confirm an action.
- Chat malformed send/close acknowledgements preserve the client-message
  identity. Positive replay, deleted-message nullable receipt, cursor ordering,
  initial subscription/rejoin recovery and queued refreshes remain covered.
- Notification missing delivery/read state, owner mismatch and ambiguous
  mark-read acknowledgements are covered. Five actual-widget cases cover cached
  clearing, stale already-read callbacks after same-user re-login, late single
  acknowledgement, late mark-all acknowledgement and session invalidation.
- BioPay missing token/state/identity, changed instruction/amount/channel,
  mismatched action state and external confirmation source remain unknown.
  Positive full-row and resolve-projection responses remain supported.

## Rendered payment callback origin

The final account review found that a retained recovery callback could recapture
the replacement account, and retained library actions could consult mutable
view state. Composer and library now capture an account snapshot and
`AccountActionToken` when rendering each private action, refresh and navigation
callback. Composer actions also retain the originating controller. Dispatch
requires the original token, the current service generation and the identical
view snapshot/controller. Explicit recovery from a newly rendered view can load
the current account; a retained callback cannot use that recovery to act as the
new account. Request-editor actions, source-sheet navigation and support/share
callbacks use the same originating view checks. Post-await publishing and
navigation retain their existing generation and operation guards.

`test/features/biopay/payment_rendered_callback_origin_test.dart` exercises
actual callbacks taken from rendered widgets, including different owners and
same-owner re-login. The matrix invokes retained refreshes before and after a
fresh recovery, and retained private actions after a new workspace and quote.
It asserts zero added service requests, contact picker dispatches, provider
opens, clipboard writes and navigation changes. Current account positives cover
request/template creation, recent favorite, pay-again, incoming acknowledgement,
contact selection/resolve, draft save, comparison/review, preparation/handoff,
reported completion, activity navigation and expiry selection. Three additional
Composer cases reject malformed injected workspaces, then accept complete
responses through the current refresh. The strict successful write receipt and
uncertain outcome contracts remain in the service/controller boundary tests.

## Local validation

Pinned runtime: Flutter 3.44.3 / Dart 3.12, using
`/Volumes/PRO-G40/Development/Flutter/flutter_3_44_codex/bin`.

- Combined focused run: **227 tests passed across 28 files**, covering wallet,
  admin, scheduled trips, BioPay, chat/realtime, notifications, member-ID parity
  and discovery card rendering.
- Subsequent BioPay state/source and request-loss run: **9 tests passed across 2
  files**. These include overlapping earlier cases; the two runs are not a
  distinct-test total.
- Focused static analysis covers the changed production boundaries and the
  focused test files: **No issues found**.
- The four updated release contract files passed **28 tests** and focused
  static analysis. Their assertions follow the notification route validator,
  realtime conversation subscription, explicit Plus preview gate and typed
  Nearby distance rendering without depending on source whitespace.
- Final workspace/receipt/parity/navigation compatibility run: **156 tests
  passed across 9 files**, including eight injected-workspace/history widget
  cases and complete link/template/pay-again positive receipts. This run overlaps
  earlier focused coverage; it is not an additional distinct-test total.
- Final analysis of the workspace consumer, shared synthetic fixture, receipt
  tests, workspace widget tests and member-ID parity test: **No issues found**.
- Root's final admin route receipt run passed **18 tests**, including complete
  new/existing SQL rows, transition versions, timestamp normalization, eleven
  persisted-field mismatches and an actual HTTP successful but stale receipt
  classified as unknown. Evidence: `/tmp/mobio-route-receipt-final.log`.
- Repository structure check passed with Flutter 3.44.3 (2,971 source/document
  files at the final check). `git diff --check` passed.

The aggregate report owns full-repository analyzer/tests, release-script,
secret-scan and platform outcomes. There are no deferred fixes for the
enumerated owned required-state, identity/correlation and notification callback
defects. External rollout and acceptance are separate from these local source
and test results.

## Scheduled departure-time completion correction

The final independent review found that nonempty `departure_time` values could
still pass the row adapter and then be clamped or replaced by current time in
edit/occurrence helpers. `TripWireRecord.parseDepartureTime` now returns typed
hour/minute values only for canonical SQL HH24:MI or valid historical AM/PM
clock values. Invalid hours/minutes, partial values and trailing garbage fail
before publication. Edit prefill and occurrence sorting/timestamps use the same
parser; noon/midnight retain their exact meaning. The date helper also requires
a valid date-only value rather than substituting today. The deliberate 90-day
recurrence horizon remains the explicit behavior for an absent optional end date.

New boundary/edit/occurrence regressions include impossible and partial clocks,
a malformed date, canonical 24-hour values, valid legacy 12-hour values and exact
midnight/noon UTC occurrences. Current integrated evidence is in the aggregate
report; these changes do not alter product scope or introduce route calculations.

Final isolated Trip verification: all 38 cases passed in the five domain, edit
state, service, account-race and mutation-receipt test files. This run covers the
strict departure correction and its valid SQL/legacy cases. Repository-wide
Flutter integration remains pending in the aggregate report.
