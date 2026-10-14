---
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [designing]
---

Our Swift backend is a modular monolith, package acme-backend, with Users, Catalog, and Billing modules and one Postgres database; it serves gRPC to our apps. Billing now has to live behind a PCI boundary the rest of the system must not enter, and it will be released by a separate team. Before publishing, the Catalog module's PublishItemUseCase calls the SubscriptionClient port declared in CatalogCore; the executable satisfies it with BillingSubscriptionClient in Sources/Acme/Ports/, which calls Billing's CheckSubscriptionUseCase. The shared authentication, persistence, and testing targets and every module's .proto files live inside acme-backend today. Explain how Billing becomes its own service and what changes for Catalog, and flag anything you need us to decide. Write it to ./split.md.
