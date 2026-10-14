---
type: llm
focus: { source: file, path: acme-library/Sources/Acme/Serve/Serve.swift }
---

PASS if all of these hold in Serve:
- One root builds both a Hummingbird `Application` and one `GRPCServer` over the same use cases, and both are entries of the same single `ServiceGroup`.
- The router's identifying tier adds `BearerAuthenticationMiddleware` (over a `JWTAuthenticator<UserIdentity>`) followed by `UserSettingsMiddleware`, and the member and loan routes that need a caller sit behind `IsAuthenticatedMiddleware`; sign-up and sign-in sit outside the bearer middleware.
- The `GRPCServer` registers both modules' service conformances and applies `BearerAuthenticationInterceptor` and then `UserSettingsInterceptor` by descriptor to the members and loans services.

FAIL if there are two roots, two `ServiceGroup`s, a server or application per module, either transport missing, a settings middleware or interceptor applied before its bearer counterpart, or an interceptor applied per method.
