---
type: llm
---

PASS if the administrator's list-all use case takes `subject: UserIdentity`, checks `.admin` in its own body throwing its own `.forbidden`, and runs over a scope that only the internal-role database adopts; the create use case takes `subject:` and runs its repository call inside `database.withTransaction`; and the HTTP handlers only translate the use cases' typed errors into RFC 9457 problem details.
FAIL if authorization is decided in a controller, a middleware, or a context conversion alone with no check in the use case, if a use case receives a database connection or a request directly, or if the identity type is not `UserIdentity`.
