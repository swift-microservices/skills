---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsCore/Registrations/UseCases/CreateRegistration/CreateRegistrationUseCase.swift }
---

PASS if the registration use case creates the registration inside database.withTransaction and starts the workflow through the Core port only after that transaction has committed.
FAIL if the workflow is started inside withTransaction or before the registration is committed, or the use case imports Temporal.
