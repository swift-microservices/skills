---
type: llm
---

PASS if the generated Postgres migrations create a `CreateServiceRole` migration first, a row-level security policy on the documents table whose predicate compares `user_id` to `current_setting('app.caller_user_id', true)` and mentions no role, and the serve composition applies `BearerAuthenticationInterceptor` followed by `UserSettingsInterceptor` to the user-facing gRPC service only.
FAIL if a policy references a role such as admin or service, if the interceptors are applied to the public service, if the database is built with a session object, or if the service declares its own Database or PostgresDatabase type.
