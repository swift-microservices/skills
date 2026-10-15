---
max_turns: 120
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [temporal]
---

Our Swift service "accounts" (package acme-accounts, targets AccountsCore, AccountsPostgres, AccountsGRPC, Accounts, on grpc-swift and PostgresNIO) creates a registration row when someone signs up. We need the registration to send a verification email, wait up to 24 hours for the person to click the link, and mark the registration expired if they never do. Add the durable part of this with the Swift Temporal SDK, including whatever process runs it. Write the new files under ./acme-accounts and finish with a short summary of what runs where.

Use these paths for the main pieces: Sources/AccountsWorkflows/EmailVerification/EmailVerificationWorkflow.swift, EmailVerificationActivities.swift, and TemporalEmailVerificationWorkflowClient.swift beside it; the Core port in Sources/AccountsCore/Registrations/EmailVerification/EmailVerificationWorkflowClient.swift; the registration use case that starts the workflow in Sources/AccountsCore/Registrations/UseCases/CreateRegistration/CreateRegistrationUseCase.swift; the use case that marks a registration expired in Sources/AccountsCore/Registrations/UseCases/ExpireRegistration/ExpireRegistrationUseCase.swift; the worker's database scope in Sources/AccountsPostgres/Scopes/PostgresAccountsWorkerScope.swift; the worker's composition root in Sources/Accounts/Worker/Run.swift; and the Temporal parts of the existing serve composition root in Sources/Accounts/Serve/Serve.swift (an excerpt of what changes is fine). The executable's Sources/Accounts/Database/Migrations.swift currently adds CreateServiceRole, CreateInternalRole, CreateRegistrationsTable, and CreateRegistrationsRLSPolicy, in that order, and all four are applied in production; write that file as it should read after your change.

Add the workflow's tests under Tests/AccountsWorkflowsTests, with the end-to-end workflow tests in EmailVerificationWorkflowTests.swift. We deploy often, so a code change must not break verifications that are already waiting when it ships; put the check for that in Tests/AccountsWorkflowsTests/EmailVerificationWorkflowReplayTests.swift.

Temporal is self-hosted and requires client certificates; its credentials are a separate pair from the service's, because one Temporal server serves both our environments. Include the client and worker credential configuration and reload lifecycle; credentials are mounted as files and renewed by the deployment.
