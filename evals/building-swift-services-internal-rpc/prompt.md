---
max_turns: 25
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building]
---

Our Swift service "billing" (package acme-billing, targets BillingCore, BillingPostgres, BillingGRPC, Billing) needs a new RPC that the entitlements worker calls to mark a purchase as fulfilled. Nothing about it involves a signed-in user. Add the use case, the gRPC handler, and whatever the serve command needs so the worker can call it, and explain how the worker is authenticated when it does. Create the new files under ./acme-billing and summarize.
