---
max_turns: 25
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building]
---

Our Swift service "billing" (package acme-billing, targets BillingCore, BillingPostgres, BillingGRPC, Billing) needs a new RPC that the entitlements worker calls to mark a purchase as fulfilled. Nothing about it involves a signed-in user. Add the use case, the gRPC handler, and whatever the serve command needs so the worker can call it, and explain how the worker is authenticated when it does. Create the new files under ./acme-billing and summarize.

The production identity authority is `identity.prod.acme.example`. Billing is `https://identity.prod.acme.example/billing`; only `https://identity.prod.acme.example/entitlements-worker` may fulfill purchases. The audit worker has valid credentials in the same identity authority but must not fulfill purchases. We also have a separate staging identity authority with an identically named worker. Our identity provider already supplies certificate chains, private keys, and trust bundles; do not implement issuance. Include the worker client setup and focused authorization test sketches.

Use native mTLS with explicit environment roots and full DNS hostname verification. Billing is dialed as billing.internal.acme.example; users and catalog, when needed, are users.internal.acme.example and catalog.internal.acme.example. Certificates carry those assigned DNS SANs alongside HTTPS caller identities. The external renewal process supplies chain/key files; standard timed reloaders run in the service group.
