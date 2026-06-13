# Play Service-Account Retention Evidence

Date: 2026-06-12
Decision owner: Jean Bosco
Google Cloud project: `easymoai`
Service account: `firmos-agents@easymoai.iam.gserviceaccount.com`
Package: `rw.mobi.app`

## Decision

The current Play service-account key is retained as-is. Do not rotate, revoke,
or replace this key as part of this release pass.

## Basis

- The app is already live/uploaded with this credential path.
- The local Play service-account JSON at
  `/Users/jeanbosco/Downloads/easymoai-208b85b24685.json` is structurally valid.
- The service-account identity matches the existing successful Play upload
  evidence in `docs/release/evidence/play-console-upload-2026-06-12-v13.md`.
- The release config/signing gate passed using this retained key, the recovered
  upload keystore, and the existing `.env`.

## Boundary

No secret values are recorded here. This file is an explicit owner acceptance
that key retention replaces rotation/revocation for this release gate.

