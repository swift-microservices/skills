---
type: llm
focus: { source: file, path: acme-api/Package.swift }
---

PASS if the manifest declares exactly two source targets, API and the Acme executable, plus an APITests test target; no Core or Postgres target and no database driver or swift-persistence dependency; the API target runs the OpenAPIGenerator plugin. The executable directly links AuthenticationSPIFFE (swift-authentication-spiffe 0.2.0 or compatible published version), AuthenticationSPIFFEGRPC (swift-authentication-grpc 0.3.0 or compatible published version), and its NIO Posix transport, even though the gateway has no incoming internal RPC service. It also links X509 if its composition directly parses certificate/key material.
FAIL if a Core, Postgres, or repository target exists, a database dependency is declared, the APITests test target is missing, the generator plugin is absent, or SPIFFE composition types lack their direct product dependencies. Do not require the API handler target to depend on SPIFFE when only the executable constructs TLS.
