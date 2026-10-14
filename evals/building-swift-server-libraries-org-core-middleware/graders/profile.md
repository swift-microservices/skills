---
type: llm
focus: { source: file, path: AGENTS.md }
---

PASS if AGENTS.md's product boundaries now say that `AcmePersistence` also holds the Hummingbird binding (`UserSettingsMiddleware`) beside the gRPC interceptor, and that it depends on Hummingbird for it, while `AcmeAuthentication` stays free of transport dependencies.
FAIL if AGENTS.md does not mention the HTTP middleware, or places it in a new product or in `AcmeAuthentication`.
Grade only against these criteria; do not fail for issues they do not mention.
