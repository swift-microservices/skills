---
type: llm
---

PASS if the composition root builds one `GRPCServer` registering both modules' generated-service conformances, applies `BearerAuthenticationInterceptor` followed by `UserSettingsInterceptor` to the two user-facing proto services (`Acme_Users_V1_UserService` and `Acme_Catalog_V1_ItemService`) by descriptor and nothing to the public ones, builds one `JWTAuthenticator<UserIdentity>` from the public key, and registers migrations as `CreateServiceRole` first and then each module's migration list in order; each module has its own Core, Postgres, and GRPC targets and no module target imports another module's targets; and the item-creation use case checks `.admin` in its own body.
FAIL if there is a server per module, if an interceptor is applied per method or to a public service, if the executable declares a second executable or the modules are separate packages, if a module imports another module's Core, Postgres, or GRPC target, if a policy references a role, or if authorization for item creation is decided in a handler or an interceptor.
