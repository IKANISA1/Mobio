# Controlled store-review access

Prepared 1 October 2026. Runtime integration is in progress under CR02/CR23;
this runbook does not assert that the current deployed service or submitted
binary implements the complete synthetic journey. Release remains NO-GO until
the exact candidate and deployed controls pass the acceptance below.

## Provision and enable

Use the approved Mobio project and a named release owner. Never substitute a
different connected Supabase project. Record the change reference, deployment
identity and candidate digest; keep service credentials, reviewer phone/code,
Auth password and bearer tokens outside the repository, public site and logs.

1. Provision a dedicated Auth UUID with provider `store_review`, a passenger or
   driver role, an unguessable internal email and no phone. Do not reuse a real
   consumer, Admin, phone owner or historical ordinary review account. Confirm
   no production profile, membership, grant, face record, Storage object, push
   token, financial record or contact alias exists for the new UUID.
2. Register it permanently through service-only
   `rpc_register_store_review_principal` with the change reference. This
   append-only registration continues to exclude production authority if
   metadata, phone or grants are changed later. Do not directly regrant private
   review tables to clients or remove the registry row during cleanup.
3. Configure the Edge secret store with `STORE_REVIEW_PHONE`, `STORE_REVIEW_OTP`,
   `STORE_REVIEW_USER_ID`, `STORE_REVIEW_GENERATION` and
   `STORE_REVIEW_SUPABASE_ORIGIN`. The origin must exactly match the approved
   project origin. Credentials have no public or compiled-client default.
4. Use service-only `rpc_configure_store_review` with a strictly increasing
   generation, the registered UUID, an explicit finite window no longer than
   30 days, fixture version `mobio-marketplace-v1` and the change reference.
   Start disabled until the deployed readback and exact binary are ready.
5. Enable only the approved window. Read back effective DB settings and Edge
   configuration without exporting secrets. Missing, mismatched, disabled or
   expired configuration must reject review admission. An enabled row alone
   does not prove deployed Edge integration or native task acceptance.

Each issued Auth SID receives a separate lease of at most one hour. Refresh
does not extend that lease. Private store instructions must explain how to
request a fresh challenge when review access expires. Selecting Passenger or
Driver changes the synthetic UI task; it does not promote the reviewer to an
Admin or change its production account role.

## Candidate acceptance

Exercise the actual deployed login handlers and the submitted signed binary.
Record success, failure and provider denial outcomes without logging codes,
passwords, access/refresh tokens, real users or biometric payloads.

- Send consumes the shared ordinary phone/source/global rate buckets. Verify
  requires the opaque current challenge, current generation and configured
  credential. No literal fallback or ordinary user factory may admit review.
- The restored exact Auth user/SID must pass fresh review status. Pending,
  cold-started, resumed, expired, disabled, rotated and revoked access keeps
  synthetic tasks locked until that status is current.
- Complete the declared passenger/driver browse, scheduled-post create/view/
  edit/cancel, chat and profile demonstrations with coherent bundled data.
  Record which optional capability demonstrations are implemented. A state-only
  demonstration cannot stand in for real device/provider acceptance.
- Prove no production REST/RPC/Storage/private Realtime access, Admin mutation,
  Google request, Face processing, push registration, billing operation, real
  message/contact/share/dialer action or arbitrary NFC operation can occur.
  Repeat denial after reviewer metadata/phone/grant tampering in an isolated
  authorized fixture. Keep normal consumer and fresh Admin positive controls.
- Test exact signed Android/iOS links, foreground permission/lifecycle tasks
  and current policy/store declarations on supported devices. Store console
  access instructions must match the exact candidate and approved window.

## Rotate, revoke and clean up

Increment the DB generation to disable or rotate access; old leases must close
immediately even when their access JWT has remaining lifetime. Update private
Edge credentials for the new generation, then re-enable only after readback.
For an individual issued SID, use service-only
`rpc_revoke_store_review_session` with its user ID, session ID and change
reference. The client revoke endpoint may select only its validated caller SID.

Verify old status returns inactive and old production requests remain denied.
Cancel pending local review actions, native continuations and retained task
state. Rotate the Auth internal password as appropriate and revoke its real
Auth sessions using the tested provider operation. Do not infer session
revocation from password rotation alone. Retain the permanent principal
registry and required change evidence; do not delete protected historical
records or real consumer data as part of reviewer cleanup.

Reconcile the historical ordinary review identity separately before any
hosted demotion or deletion. Public credential removal does not itself revoke
an existing session, rotate a credential or establish containment. Publication,
provisioning and deployed readback remain distinct from local implementation.
