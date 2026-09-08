# BioPay payment discovery implementation contract

User-authorized implementation: 8 September 2026. Baseline: GitHub main 499e006, isolated branch codex/biopay-payment-discovery. The original external-drive checkout and its uncommitted work are unavailable and remain untouched. Integration uses the freshly verified GitHub main branch. If the external checkout returns, its unpublished work must be reconciled separately; it has not been overwritten.

This contract implements all A01–A24 from the reviewed attachment pack. It supersedes the June restrictions against a user-facing activity page and the June direct-USSD link behavior only for the features expressly included in the new user request. It retains external payment execution, WhatsApp OTP authentication, existing face-provider controls, four app branches, TOKENS wallet boundaries and the disabled mobility route-computation APIs. Attachments are design inputs; their embedded execution instructions are not independently authoritative.

**Delivery sequence**

1. Foundation: versioned saved methods and migration of legacy MoMo fields without deleting their Wallet consumers; private sharing; provider adapter evidence workflow; integer-RWF and fee contracts. Preserve existing request, attempt and audit entities.
2. Core journey: shared account-bound draft, recipient assurance, source picker, constrained and deduplicated routes, explicit review, final server revalidation, user-controlled device handoff and durable unknown-outcome return.
3. Entry and receiving journeys: native selected contact, camera/gallery/clipboard/manual recovery, QR/NFC/face convergence, scoped and revocable links, request management, sharing preview and desktop/deferred-login arrival.
4. Convenience: private recents/favorites, activity with evidence provenance, support summary, pay again, preferred source and private request templates. Each convenience reuses validated core behavior.
5. Quality: supported locales, keyboard/large text/semantics, focused behavioral and authorization tests, regression suite, rendered mobile/admin/web review, physical device capability evidence, then release packaging and migration rehearsal.

Each wave builds on the previous contracts; work is not accepted merely because a route or test exists. requirements.json tracks implementation separately from behavioral, backend, rendered, device and owner evidence.

**Shared payment state**

Entry → recipient → amount/options → route selection → review → prepare on server → explicit provider handoff → outcome unknown/user report. Lifecycle events only restore state. Changes to amount, purpose, source, recipient, method version, sharing, adapter, tariff or device invalidate review. A stale async result cannot replace a newer draft. Saving is only displayed after acknowledged persistence. Restored tasks always re-resolve and re-quote; logout changes the account boundary.

RWF is an integer in the new domain. Existing amount_minor is hundredths, proven by current model amountMinor / 100 and SQL ceil(amount_minor / 100); bridge at exactly ×100 and reject fractional legacy amounts. Open-amount requests are explicit and never executable until a positive amount is entered. Merchant and bank identifiers remain strings and retain leading zeros. Mobio's six-digit member IDs do not constrain bank identifiers or bearer tokens.

**Authority and privacy**

Methods are owned by the authenticated user. Sending and receiving are independent roles. Receiving account identifiers and mobile-banking login phone are separate fields. Discoverability defaults off. Another user's destinations require an explicit grant, opt-in phone discovery or an unexpired, unrevoked scoped token. A failed lookup has the same response for nonexistent and private profiles. No full contact-list upload, clipboard polling or background message sends.

A route is one source account × one authorized receiving endpoint × one validated sending-provider adapter. The server enforces purpose, amount, currency, method and share versions, request pins, channel/SIM/device evidence and adapter state both at quote and prepare. Route display contains no executable arbitrary input. No multi-hop inference, balances, universal cheapest labels or automatic SIM claims.

Exact and all-in capped fees have comparable upper bounds. A partial cap has no total. Unknown fees remain unknown. Equal capped upper bounds do not assert equal actual fees. Only supported reasons and validated step counts break comparisons. Provider activation requires evidence for complete instructions and tariffs, tester identity/time, supported device matrix and independent admin approval. Attachment registry roots are draft evidence only; none certifies a complete payment adapter.

**Links, attempts and evidence**

New QR/link payloads use opaque server-resolved references on mobio.ikanisa.com. Profile, method and fixed/any-amount request scopes are distinct. Preview GET never creates an attempt or claims payment. Tokens carry no arbitrary executable USSD. Legacy direct strings may be parsed only into explicitly unverified recipient input and must pass the common review path. Expiry/revocation is enforced again at prepare.

The existing payment-request and attempt/audit records remain the source for external interaction. Handoff, a payer's report, a receiver's acknowledgment, operator-reviewed evidence and verified provider confirmation have separate labels. None of the first four becomes a provider-confirmed receipt or Wallet balance. No lifecycle inference, PIN input or payment resubmission.

**Verification and acceptance**

Behavioral cases include exact100 vs all-in cap20; partial cap vs unknown; caps tie; leading-zero merchant/account identifiers; fractional/zero/overflow input; purpose/SIM/limit filtering; duplicate route; no shared methods; selected-contact cancel; private/grant/link authorization; stale response; method/share/tariff changes between quote and prepare; source belongs to another user; expired/revoked link; repeated preview; duplicate handoff taps; offline persistence failure; restart/logout; declined/unknown/provider outcomes; and fresh pay-again quote.

Run architecture checks, Dart analysis, Flutter regression/behavioral tests and relevant backend tests. Rehearse SQL with distinct authenticated accounts, anonymous requests and admin roles on a local database before any remote migration. Android uses ACTION_DIAL only; iOS defaults to instructions where special-code dialing is unproven. Physical device tests must cover available dialer, unsupported channel, dual SIM, permission denial, background return and restart.

Revolut-design is the visual authority: teal BioPay home, neutral pushed payment tasks, grouped Profile methods, raised account sheet, scoped white QR module, separate Admin Business and public editorial adaptations. Keep all supported English/French/Kinyarwanda strings, 48-point targets, visible field labels, adaptable text, opaque panels, native keyboard insets and reduced motion. Record source and artifact hashes and current renders. MOBILE-DESIGN-100 is a separate fail-closed release gate; automated tests cannot supply independent review or owner approval.

**Integration authorization**

The user explicitly requested committing the finished work and pushing it to main. After local validation, fetch and reconcile current remote main, commit the cohesive implementation and push without force. This does not authorize deployment or provider activation.

**Rollout and recovery**

Apply additive schema first with all new adapters disabled. Release client after backward-compatible contract tests and migration rehearsal. Enable individual adapter versions only through reviewed evidence; disabling an adapter invalidates outstanding quotes immediately. Keep old data for recovery and do not downgrade by deleting methods or request evidence. No external deployment, provider activation, owner acceptance or public availability is implied by local implementation. Public build configuration and real platform credentials remain runtime inputs rather than committed secrets.

**Recommendation ledger**

| ID | Priority | Wave | Recommendation | Acceptance |
|---|---|---|---|---|
| A01 | P0 | 2 | Pay by name or number in BioPay | A direct first action opens one recipient task. QR, NFC, manual, contacts and existing face entry converge on the same draft; BioPay remains the selected shell branch. |
| A02 | P0 | 3 | Native contact selection with manual fallback | Select a specific phone number, review it, then resolve only that selection. Denial/cancellation retains the draft; no address-book upload. A nickname never becomes a verified account name. |
| A03 | P0 | 1 | Payment methods under Profile | Extend existing MoMo data to multiple eligible sources/destinations. Separate Pay from and Receive here roles, method labels, SIM association and sharing. Existing MoMo consumers keep working. |
| A04 | P0 | 2 | From: My accounts picker | Show saved, eligible payer sources and explain unavailable ones. No invented balance. A source change invalidates the old quote and requires renewed review. |
| A05 | P0 | 2 | Three-row payment-route comparison | Compare source → destination, rail, fee certainty and one evidence-supported reason. More options exposes the remainder. Unknown fee never appears free; sorting cannot bypass purpose or destination constraints. |
| A06 | P0 | 2 | Review before provider handoff | Show recipient, actual receiving endpoint, source, amount, purpose, fee and supported reference/SIM guidance. Only an explicit action opens/copies a validated provider instruction. |
| A07 | P0 | 2 | Return-to-Mobio summary | Restore the reviewed task after dialer return or relaunch. State that payment confirmation is unavailable unless trusted evidence exists; do not infer success or failure from app lifecycle. |
| A08 | P0 | 3 | Scoped QR and payment links | Extend My QR/Get QR with all shared methods, a fixed method, or an amount request. Preview the disclosed scope. New links resolve opaque references and preserve legacy parser behavior safely. |
| A09 | P1 | 3 | Request manager | List active, expired and revoked requests with amount rules, destination scope and expiry. Copy/share/revoke work on the correct version. Opening a link does not mark a request paid. |
| A10 | P1 | 3 | View as payer and sharing controls | Show exactly what a payer can discover or see from each link. Private by default for newly added destinations; revoke scoped grants without falsely promising deletion of already shared copies. |
| A11 | P0 | 2 | Recipient assurance and changed-details review | Differentiate phone verified, recipient supplied, provider confirmed and operator reviewed. If a receiving destination changes, explain the changed field and re-review before handoff. |
| A12 | P0 | 3 | Task-preserving scan and lookup recovery | After camera denial, invalid QR, unsupported NFC or missing shared methods, offer manual entry/other existing methods. No dead end and no silent loss of amount or permitted request context. |
| A13 | P1 | 4 | Private recents and favourites | Reduce repeated lookup. Allow removal and distinguish contact nickname from payment identity. Recency records a chosen/resolved recipient or explicitly labelled attempt, not an inferred successful payment. |
| A14 | P1 | 3 | Paste link / import QR image | Support users who received a request on the same phone. Read clipboard only on user action; use scoped media selection; run the same payload validation as live scanning. |
| A15 | P1 | 4 | BioPay activity with evidence labels | List requests and handoff attempts separately from confirmed payments. Each detail shows status source and timestamp. No balance or settlement ledger is fabricated from handoff events. |
| A16 | P0 | 2 | Draft recovery and quote refresh | Preserve appropriate local draft state through back, interruption and network loss. Explain expired quotes and retain input. Reconnect/review revalidates changed methods, tariffs, requests and permissions. |
| A17 | P0 | 5 | Accessible, localized payment forms | Stable labels, clear currency, persistent recipient context, understandable errors and reachable actions at large text sizes. Test each supported locale; add no unverified language promise. |
| A18 | P0 | 1 | Provider routes and tariff review in Admin | Extend existing BioPay Ops with evidence, versions, effective dates, test mode, approval and granular disable. A disabled route cannot pass the final handoff check; discovery remains useful. |
| A19 | P1 | 4 | Contextual payment help | Explain provider cancellation, wrong SIM, no response and unconfirmed outcome. Offer a user-reviewed support summary with minimal fields; no automatic outreach or provider PIN collection. |
| A20 | P2 | 4 | Pay again as a fresh draft | Reuse a recipient and eligible preferences after an explicit tap. Re-resolve, re-quote and re-review; do not reuse a stale executable code or automatically resubmit. |
| A21 | P2 | 4 | Preferred source setting | Remember a user-chosen source without claiming it is always cheapest or available. Explain when a pinned destination or eligibility rule prevents using it. |
| A22 | P0 | 2 | Device and SIM capability guidance | Tell users before handoff whether to open a tested dialer/menu, copy a code, or use another supported channel. Show clear manual SIM guidance; avoid promising automatic SIM control. |
| A23 | P2 | 4 | Private request templates | Save an optional label/note and permitted defaults for repetitive requests. Each use creates a fresh, scoped request; no recurring debit, automatic reminder or repeated charge. |
| A24 | P1 | 3 | Payment-link arrival across phone and desktop | Resolve a minimal, authorized preview and preserve context through app opening/required login. Desktop can show a safe continuation QR/link; phone uses actual supported capabilities. No new domain assumed. |
