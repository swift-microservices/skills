---
max_turns: 35
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [delivering, mtls]
---

Prepare deployment guidance for production billing and an entitlements worker using native mTLS. The private CA issues 30-minute leaves with identities https://identity.prod.acme.example/workloads/billing and https://identity.prod.acme.example/workloads/entitlements-worker, and assigned DNS SANs. Staging has independent roots and identity.staging.acme.example. A separate renewal container per workload can write its own credential directory. Applications use standard TimedCertificateReloader. Temporal has separate issuer credentials. The gateway also calls an unrelated managed HTTPS API.

Describe safe mounts, renewal publication, startup checks, issuer outage and expiry, root overlap/removal, emergency revocation with live streams, and concrete acceptance checks. Keep workload containers free of CA/admin credentials. Prepare artifacts and an approval checklist; do not deploy anything. Do not claim runtime evidence you have not collected.
