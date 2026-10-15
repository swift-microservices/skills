---
runs: 1
max_turns: 60
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [temporal]
---

Our Swift service "accounts" (package acme-accounts, targets AccountsCore, AccountsPostgres, AccountsGRPC, Accounts, on grpc-swift and PostgresNIO) creates a registration row when someone signs up. We need the registration to send a verification email, wait up to 24 hours for the person to click the link, and mark the registration expired if they never do. Add the durable part of this with the Swift Temporal SDK, under ./acme-accounts.

Write only these files: Sources/AccountsWorkflows/EmailVerification/EmailVerificationWorkflow.swift, EmailVerificationActivities.swift, and TemporalEmailVerificationWorkflowClient.swift beside it; the Core port in Sources/AccountsCore/Registrations/EmailVerification/EmailVerificationWorkflowClient.swift; and the registration use case that starts the workflow in Sources/AccountsCore/Registrations/UseCases/CreateRegistration/CreateRegistrationUseCase.swift. The executable's Sources/Accounts/Database/Migrations.swift currently adds CreateServiceRole, CreateInternalRole, CreateRegistrationsTable, and CreateRegistrationsRLSPolicy, in that order, and all four are applied in production; write that file as it should read once the workflow's process has its own database access. Don't build or resolve packages.
