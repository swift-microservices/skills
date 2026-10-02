---
max_turns: 80
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [temporal]
---

Our Swift service "accounts" (package acme-accounts, targets AccountsCore, AccountsPostgres, AccountsGRPC, Accounts, on grpc-swift and PostgresNIO) creates a registration row when someone signs up. We need the registration to send a verification email, wait up to 24 hours for the person to click the link, and mark the registration expired if they never do. Add the durable part of this with the Swift Temporal SDK, including whatever process runs it. Write the new files under ./acme-accounts and finish with a short summary of what runs where. Use these paths for the main pieces: Sources/AccountsWorkflows/EmailVerification/EmailVerificationWorkflow.swift, EmailVerificationActivities.swift, and TemporalEmailVerificationWorkflowClient.swift beside it; the Core port in Sources/AccountsCore/Registrations/EmailVerification/EmailVerificationWorkflowClient.swift; the registration use case that starts the workflow in Sources/AccountsCore/Registrations/UseCases/CreateRegistration/CreateRegistrationUseCase.swift; and the worker's composition root in Sources/Accounts/Worker/Run.swift.

Temporal is self-hosted and requires client certificates. Include the client and worker credential configuration and reload lifecycle; credentials are mounted as files and renewed by the deployment.
