---
type: llm
focus: { source: file, path: split.md }
---

PASS if Billing never trusts a caller-asserted identity: either the user's original token is forwarded on Billing's user-facing service and Billing verifies it itself with the issuer's public key (no signing key, and no shared symmetric key, in Billing), or the check is an internal mTLS operation that takes the user id as business data.

FAIL if Billing accepts a user id or role from request metadata as the caller, receives the private signing key, or the connection between acme-backend and Billing is not mTLS.
