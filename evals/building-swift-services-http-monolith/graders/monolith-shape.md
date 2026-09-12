---
type: llm
---

PASS if the package is one executable whose composition root mounts the modules' controllers on one Hummingbird router; the notebooks module has its own Core, Postgres, and HTTP targets and no module target imports another module's Core, Postgres, or HTTP target; the migrations begin with `CreateServiceRole` (one set of process roles, not one per module), the notebooks table has a row-level security policy whose predicate compares `user_id` to `current_setting('app.caller_user_id', true)` and mentions no role, and the identifying route tier applies `BearerAuthenticationMiddleware` followed by `UserSettingsMiddleware`, with sign-up and sign-in registered outside any authenticating middleware.
FAIL if the package declares gRPC targets or proto contracts, if a tenant table has no tenant-isolation policy, if the router applies the bearer middleware to sign-in or excludes it by a path check inside the middleware, if the tenant setting is bound per module or per connection rather than per request, if a module imports another module's targets, or if the package declares its own Database or PostgresDatabase type.
