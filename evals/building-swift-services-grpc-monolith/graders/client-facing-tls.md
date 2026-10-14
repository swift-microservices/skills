---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Serve/Serve.swift }
---

The mobile app calls this server directly through the public edge, so its gRPC listener is client-facing.

PASS if the `GRPCServer` that registers `Acme_Users_V1_UserService` and `Acme_Catalog_V1_ItemService` is served over server-side TLS that requires no client certificate: its `transportSecurity` is `.tls(...)` with client certificate verification off (or left at the `.tls` default), or a project factory whose name says server TLS, such as `.serverTLS(certificateReloader:)`; the certificate comes from configuration or a primed reloader; and callers are identified by the bearer interceptor.
FAIL if that listener uses `.mTLS(...)` or any configuration that requires a client certificate, is `.plaintext`, or registers an internal service descriptor beside the client-facing ones.
