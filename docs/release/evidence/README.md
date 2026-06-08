# Release Evidence

This folder contains safe templates for external production evidence. Do not
commit secret values, service-account JSON, keystore files, private keys,
personal data, screenshots with tokens, or Play Console credentials.

The final production gate requires existing evidence file paths for:

- Play service-account key revocation and replacement.
- Play Console internal or closed-track upload validation.

Use the `*.example.md` files as the expected shape, then store the real evidence
in a private release folder or in a secure internal system. If a private file is
used locally, pass its path to `scripts/release/go_no_go_check.sh` with the
matching environment variable.

The final gate rejects `*.example.md` paths. Example files document the evidence
shape only; they are not production proof.
