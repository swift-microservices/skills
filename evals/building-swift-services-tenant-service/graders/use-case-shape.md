---
type: llm
---

PASS if the list use case takes `subject: UserIdentity` in its signature, decides in its own body whether the subject may list every document (an administrator check throwing the use case's own `.forbidden`), and the create use case runs its repository call inside `database.withTransaction`.
FAIL if authorization is decided in a gRPC handler or an interceptor, if the identity type is named UserPayload, or if a use case receives a database connection directly.
