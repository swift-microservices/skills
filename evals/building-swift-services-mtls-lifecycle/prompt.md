---
max_turns: 35
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, mtls]
---

Design and sketch workload authentication and renewal for ./acme-ledger using the swift-microservices packages. Ledger's URI is https://identity.prod.acme.example/workloads/ledger; billing is dialed as billing.internal.acme.example. Each certificate contains its HTTPS workload URI and its assigned server DNS SANs. The platform CA issues 30-minute leaves; a separate renewal process atomically replaces chain.pem in a stable directory, preserving key.pem and bundle.pem. Temporal has separate credentials and roots. Do not implement an issuer or modify deployment.

Show native mTLS, caller principal binding, exact-identity use-case authorization, standard timed reloader ownership, and focused tests. Explain malformed replacement, parseable wrong-identity replacement, issuer outage through expiry, in-flight calls, root A+B overlap/removal and emergency revocation with existing streams. Clearly distinguish issuer responsibilities, loader checks, TLS checks and RPC checks. Keep APIs small and avoid a custom lifecycle state machine.
