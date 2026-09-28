---
type: llm
---

PASS only if the design assigns fetching/attestation/retry to the external provider integration, atomic validated updates to SPIFFETransportSecurity, and readiness plus transport/stream shutdown to the application lifecycle. It covers startup with no valid credentials, failed renewal retaining only valid material, expiry refusal/alerts, A+B overlap followed by A removal after renewal, and emergency revoke plus closure of established streams/outgoing connections. Acceptance checks exercise wrong peers, expiry, rotation, and active-connection revocation; connection age/grace and deadlines fit the stated 30-minute lifetime.

FAIL if updating files alone is claimed to reauthenticate open streams, the adapter is claimed to implement the Workload API, outages enable plaintext/expired credentials, or no component owns active-stream termination. Operational proposals must not be presented as executed deployment tests.
