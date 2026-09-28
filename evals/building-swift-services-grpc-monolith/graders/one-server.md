---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Serve/Serve.swift }
---

PASS if the composition root builds one GRPCServer registering both modules' generated-service conformances; applies BearerAuthenticationInterceptor by descriptor to the two user-facing services (Acme_Users_V1_UserService and Acme_Catalog_V1_ItemService) and nothing to the public ones; follows it with UserSettingsInterceptor only where a module has tenant tables (a users table and a catalog every signed-in user can read need none, so omitting it is correct); and builds one JWTAuthenticator<UserIdentity> from the public key.
FAIL if there is a server per module, an interceptor is applied per method or to a public service, or authentication for the user-facing services is missing.
