---
type: llm
focus: { source: file, path: acme-api/Package.swift }
---

PASS only if the manifest declares an API library and an executable composition target with direct products matching their imports. HTTP/OpenAPI code stays in API; gRPC clients, configuration, auth and lifecycle belong to the executable. Use AuthenticationGRPC for bearer propagation, GRPCNIOTransportHTTP2Posix for native TLS and NIOCertificateReloading when used. AuthenticationX509 is needed only where its types are imported; an outgoing-only gateway need not link the server certificate interceptor. No database target or private JWT signing capability belongs in the gateway. FAIL for missing product dependencies, coupling API to persistence, custom security products, or branch/path dependencies in the delivered manifest.
