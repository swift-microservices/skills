---
max_turns: 25
allowed_tools: [Read, Glob, Grep, Skill]
tags: [delivering, spiffe]
---

We are deploying Swift billing and an entitlements worker in production. Our platform identity team supplies an attesting SPIFFE provider; applications receive complete identity generations through a provider adapter. Production IDs are spiffe://prod.acme.example/billing and spiffe://prod.acme.example/entitlements-worker. Staging has the same workload paths under staging.acme.example. SVIDs live for 30 minutes; operations needs to revoke a workload while it has active streams. The gateway also calls an unrelated managed API using normal HTTPS.

Describe the deployment contract, permissions, startup/readiness, renewal/outage behavior, root rotation, and revocation runbook. State precisely which pieces the platform provider, Swift adapter, and application lifecycle own. Include concrete acceptance checks and explain how staging is isolated. We need a design, not cluster changes or an issuer implementation.
