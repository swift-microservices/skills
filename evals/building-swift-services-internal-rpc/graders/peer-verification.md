---
type: llm
---

PASS only if the worker presents its own credentials and dials billing with `clientTransportSecurity(expectedServer:)` for `spiffe://prod.acme.example/billing`, retaining a finite RPC deadline. Server and client use explicit domain-specific trust bundles through the SPIFFE adapter; peer-provided roots and operating-system roots are not substituted. Manifests/imports link the products actually named, including `AuthenticationSPIFFEGRPC` from swift-authentication-grpc 0.3.0 or a compatible published version and `AuthenticationSPIFFE` from 0.2.0 or a compatible published version. The worker needs no bearer propagation for this call.

FAIL if DNS alone or any trusted-domain server suffices, verification is disabled, or examples name SPIFFE types without their direct products. URI-only SVIDs are valid; do not demand DNS SANs.
