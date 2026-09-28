---
max_turns: 25
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building]
---

Our Swift service "billing" (package acme-billing, targets BillingCore, BillingPostgres, BillingGRPC, Billing) needs a new RPC that the entitlements worker calls to mark a purchase as fulfilled. Nothing about it involves a signed-in user. Add the use case, the gRPC handler, and whatever the serve command needs so the worker can call it, and explain how the worker is authenticated when it does. Create the new files under ./acme-billing and summarize.

The production trust domain is `prod.acme.example`. Billing is `spiffe://prod.acme.example/billing`; only `spiffe://prod.acme.example/entitlements-worker` may fulfill purchases. The audit worker has valid credentials in the same domain but must not fulfill purchases. We also have a separate staging domain with an identically named worker. Our identity provider already supplies certificate chains, private keys, and trust bundles; do not implement issuance. Include the worker client setup and focused authorization test sketches.
