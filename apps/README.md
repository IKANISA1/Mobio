# Separate applications

`momobio_sms_bridge/` is the existing Android operator utility. It retains its
package identity, build definition and scripts. Historical QA evidence is in
`../docs/release/evidence/momobio-sms-bridge/`; new runs write to `../build/qa/`.

Mobile and web/admin share the root Flutter application. The public site is
`../landing/`. There are no placeholder app shells under this directory.
