# BioPay scan recovery — 6 September 2026

The QR scanner remains usable after unrelated QR content, malformed payloads, failed lookups, and unsuccessful dialer handoffs. Errors explain the failure. **Scan again** restarts camera detection so the same code can be retried despite duplicate filtering. In-flight and successful USSD handoffs remain guarded against repeated launches; a successful handoff requires an explicit new scan.

Camera errors now distinguish denied access, unavailable hardware, and other failures. Denied access offers **Open Settings** and **Retry camera** on native platforms; web copy directs users to browser permissions. The camera restarts on app resume, serializes stop/start operations, and hides the torch when no preview is available. Recovery uses semantic colours in both light and dark themes and scrolls at enlarged text sizes.

## Validation

- Dart analysis: no issues.
- BioPay suite: 38 tests passed, including ten new recovery regressions using simulated camera channels and dialer results.
- Full Flutter suite: 551 tests passed.
- Scanner screenshots reviewed at 390×844 and 430×932 in dark mode and 390×844 in light mode; updated only these affected golden baselines.
- Repository structure, secret-pattern scan, and whitespace checks passed.
- iOS simulator build succeeded; installed over the existing Mobio app without resetting its session.
- Flutter release web build and combined website/admin PWA bundle validation passed.

Native UI verification on the iPhone 17 simulator confirmed the denial explanation, retry without a stuck state, and opening iOS Settings. This simulator opened the Settings root. The return-to-app check is recorded with the local evidence. Permission remains denied on the simulator; automated tests cover permission becoming available on resume.

Local evidence: `build/qa/biopay-scan-fix-20260906/` (ignored), including test/build logs and the camera-recovery screenshot.

This verification does not establish physical-camera capture or carrier USSD execution. No payment, face capture, provider configuration, or public deployment was performed. Android binaries were not rebuilt in this batch.
