---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Serve/Serve.swift }
---

PASS if all of these hold in Serve:
- One `GRPCServer` registers both modules' service conformances (users and catalog), and one `JWTAuthenticator<UserIdentity>` is built for it (from a key read through configuration).
- `BearerAuthenticationInterceptor` is applied by descriptor (`.services([...])`) to both `Acme_Users_V1_UserService` and `Acme_Catalog_V1_ItemService`.
- `UserSettingsInterceptor`, where present, comes after the bearer interceptor and is never applied to `Acme_Catalog_V1_ItemService` (catalogue items are not tenant rows); applying it to the users service or omitting it there are both correct.

FAIL if there is a server per module, an interceptor is applied per method, authentication is missing for either service, or the settings interceptor precedes the bearer interceptor.
