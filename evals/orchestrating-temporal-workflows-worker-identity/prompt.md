---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
tags: [temporal]
---

Our entitlements Temporal worker (Swift, grpc-swift, our usual mTLS mesh) has an Activity that must tell the billing service to mark a purchase fulfilled for a given user. The billing service has BillingPublicService, BillingService (needs a bearer token), and BillingInternalService. Which service should the worker call, how does billing know it is our worker and not some random client, and how does the user end up in the request? Answer in a few paragraphs with the relevant code sketch.

Use production IDs `https://identity.prod.acme.example/entitlements-worker` and `https://identity.prod.acme.example/billing`. An authenticated audit worker is not allowed to fulfill purchases. The identity provider is wired separately. Show where that restriction belongs and how the worker chooses the billing endpoint identity.

Use native mTLS with explicit environment roots and full DNS hostname verification. Billing is dialed as billing.internal.acme.example; users and catalog, when needed, are users.internal.acme.example and catalog.internal.acme.example. Certificates carry those assigned DNS SANs alongside HTTPS caller identities. The external renewal process supplies chain/key files; standard timed reloaders run in the service group.
