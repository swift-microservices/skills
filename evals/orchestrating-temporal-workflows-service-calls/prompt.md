---
max_turns: 60
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [temporal, mtls, workers]
---

The billing service has a Temporal workflow that reconciles a payment and asks accounts to update a subscription. The workflow may run for days and must continue after the initiating user's session expires. Billing owns payment rows; accounts owns subscription rows. Both services and the self-hosted Temporal frontend require client certificates. Billing's deployment supplies distinct files for service-network and Temporal credentials.

Write focused Swift excerpts under ./acme-billing: the worker's composition root at Sources/Billing/Worker/Run.swift, the Activity container at Sources/BillingWorkflows/PaymentReconciliation/PaymentReconciliationActivities.swift, its Core Activity-service port at Sources/BillingCore/PaymentReconciliation/Activities/PaymentReconciliationActivityService.swift, and the accounts gRPC consumer adapter at Sources/BillingGRPC/Clients/GRPCAccountClient.swift. Under ./acme-accounts, show the receiving side: the handler at Sources/AccountsGRPC/Accounts/AccountInternalService.swift and the use case it calls at Sources/AccountsCore/Subscriptions/UseCases/UpdateSubscription/UpdateSubscriptionUseCase.swift. Assume the workflow and the generated AccountInternalService contract already exist, and the workflow's input carries the payment id and the subscription id. Include the configuration scopes and reload lifecycle, and summarize what is persisted in workflow history versus constructed at worker startup. No complete package scaffold, dependency resolution, or execution is needed.
