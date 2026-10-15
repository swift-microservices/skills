---
runs: 1
max_turns: 60
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, grpc, mtls]
---

Our Swift billing service receives payment-provider webhooks and calls the accounts service to record a subscription change. This operation has no signed-in user. Accounts also exposes a separate user-facing profile service used by the gateway. Both services run on a private network; deployment mounts certificates, keys, and CA bundles and renews the leaf credentials while processes are running.

Write focused Swift implementation excerpts under ./acme-billing and ./acme-accounts: the billing-side Core port and gRPC adapter, the accounts-side internal handler and input-only use-case boundary, and each executable's transport configuration and lifecycle. Use the existing AccountInternalService and AccountService generated contracts; assume persistence, protobuf conversions, and business rules already exist. Show how the user-facing service remains authenticated. Put each executable's composition root at Sources/Billing/Serve/Serve.swift and Sources/Accounts/Serve/Serve.swift in its package, the accounts internal handler at ./acme-accounts/Sources/AccountsGRPC/Accounts/AccountInternalService.swift, the billing port at ./acme-billing/Sources/BillingCore/Ports/AccountClient.swift, and its gRPC adapter at ./acme-billing/Sources/BillingGRPC/Clients/GRPCAccountClient.swift. Include the executable's direct package products needed for transport reloading in ./dependencies.md.

These are offline excerpts, so do not build, resolve packages, or claim runtime verification. Do not scaffold unrelated features.
