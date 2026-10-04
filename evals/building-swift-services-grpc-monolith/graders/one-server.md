---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Serve/Serve.swift }
---

PASS if the composition root builds one GRPCServer registering both modules' generated-service conformances; applies BearerAuthenticationInterceptor by descriptor to the three signed-in services (Acme_Users_V1_UserService, Acme_Catalog_V1_ItemService, and Acme_Catalog_V1_ItemAdminService) and nothing to the public ones; follows it with UserSettingsInterceptor only on self services and only where a module has tenant tables (a users table and a catalog every signed-in user can read need none, so omitting it is correct); and builds one JWTAuthenticator<UserIdentity> from the public key.
FAIL if there is a server per module, an interceptor is applied per method or to a public service, or authentication for the signed-in services is missing.
