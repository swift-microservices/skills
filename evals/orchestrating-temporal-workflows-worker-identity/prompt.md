---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
tags: [temporal]
---

Our entitlements Temporal worker (Swift, grpc-swift, our usual mTLS mesh) has an Activity that must tell the billing service to mark a purchase fulfilled for a given user. The billing service has BillingPublicService, BillingService (needs a bearer token), and BillingInternalService. Which service should the worker call, how does billing know it is our worker and not some random client, and how does the user end up in the request? Answer in a few paragraphs with the relevant code sketch.
