---
max_turns: 15
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [designing]
---

Our Swift backend is a modular monolith, package acme-backend, with Users, Catalog, and Billing modules and one Postgres database; it serves gRPC to our apps. Billing now has to live behind a PCI boundary the rest of the system must not enter, and it will be released by a separate team. The Catalog module's PublishItemUseCase calls Billing's CheckSubscriptionUseCaseProtocol before publishing. Explain how Billing becomes its own service and what changes for Catalog, and what must not be done without a decision from us. Write it to ./split.md.
