---
type: llm
---

PASS only if the review identifies both defects in Sources/Ledger/Identity/IdentityRuntime.swift with file-and-line evidence: ready always returns true after expiry/revocation; emergencyRevoke never invokes the supplied closeTransports callback, leaving active streams/outgoing transports to continue. Recommend delegating readiness to security.isReady and invoking shutdown/drain during revocation. Note that sequential coherent updates, retaining valid state after update failure, required peer binding, and bounded server connection age are positive supplied behaviors.

FAIL if it claims revoke itself closes every stream, misdiagnoses the coherent serial update loop as necessarily accepting expired material, invents missing-provider defects contrary to REVIEW-SCOPE.md, or claims to have executed tests.
