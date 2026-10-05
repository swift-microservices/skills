---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Serve/Serve.swift }
---

PASS if the composition root builds one GRPCServer registering both modules' generated-service conformances; applies BearerAuthenticationInterceptor by descriptor to both services (Acme_Users_V1_UserService and Acme_Catalog_V1_ItemService), whose handlers then require a user or an administrator per RPC, the item-creation handler an administrator; follows it with UserSettingsInterceptor only where a module has tenant tables (a users table and a catalog every signed-in user can read need none, so omitting it is correct); and builds one JWTAuthenticator<UserIdentity> from the public key.
FAIL if there is a server per module, an interceptor is applied per method, a signed-in or administrator handler calls its use case without first requiring the principal, or authentication for the services is missing.
