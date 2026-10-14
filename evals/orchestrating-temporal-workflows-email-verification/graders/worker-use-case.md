---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsCore/Registrations/UseCases/ExpireRegistration/ExpireRegistrationUseCase.swift }
---

PASS if the use case takes `input:` alone (no `subject:` or user identity), is generic over a `Database` whose scope conforms to its own scope protocol, runs its write in `database.withTransaction`, and makes the expiration retry-safe (for example a state transition guarded in the update, so a repeat attempt is a no-op or a typed error).
FAIL if it takes a user identity or token, imports Temporal or PostgresNIO, or blindly overwrites a registration that was verified meanwhile.
