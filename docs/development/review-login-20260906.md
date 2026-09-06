# Review-only OTP instructions — 2026-09-06

The owner confirmed that the existing Google Play review phone remains
review-only. Its established review credential and verification behavior are
unchanged. This account intentionally receives no WhatsApp message.

The reported failure was reproduced in the production audit record: the
request was marked `google_play_review_login=true`, but the response and UI
claimed ordinary WhatsApp delivery. `send-login-otp` now returns
`deliveryMode: review_code` with truthful instructions for this account. Ordinary
requests return `deliveryMode: whatsapp`; no review credential is included in the
response.

The Flutter login service reads that response field. The existing authentication
screen shows “Use your review code” and explains that no WhatsApp message is sent.
Its retry action says “Request again”. Changing the number clears the review
instructions; ordinary login keeps the WhatsApp instructions. The existing Mobio
authentication layout, colors, verification flow and role behavior are retained.

## Backend deployment

Production `send-login-otp` advanced from version 27 to **28**. The deployment
was based on the fetched active version, changing only the response instructions
and shared response helper. The remaining deployed files were preserved; broader
source changes already present in the repository were not bundled into this fix.
JWT verification remains enabled. Readback confirmed every deployed file matches
the prepared patch. `verify-login-otp` was not changed or redeployed.

The corresponding source change is included in the repository for subsequent
full deployments. The redacted diagnosis and exact deployment bundle are retained
locally under ignored `output/review-otp-fix-20260906/` and
`output/otp-diagnosis-20260906/`.

## Validation

- Flutter analysis: passed, no issues.
- Full Flutter suite: **526 passed**, including existing visual goldens.
- Service response tests: **8 passed**, including review, ordinary and legacy
  responses. The request contract is unchanged.
- Backend type checks and tests: **29 passed**. Review-account tests now run in
  the regular backend verification script.
- Script tests: **19 passed**; repository structure and diff checks passed.
- New widget tests cover review instructions, retry text, number changes,
  enlarged text with keyboard, and the existing code-verification flow.

## Native and live verification

The rebuilt iPhone simulator app displays the review instructions without
claiming a WhatsApp send. Entering the existing review credential opens Mobio
Home. The production audit record at `2026-09-06T08:06:46.684989Z` reports
`status: verified` and `google_play_review_login: true`.

The iOS simulator build and combined website/admin release package passed.
The simulator is signed in and visible at [Mobio preview](http://localhost:64320/).
Native screenshots are retained in the ignored output directory. These checks
establish review-account sign-in; they do not establish delivery of real WhatsApp
messages, physical-device push, or a store release.
