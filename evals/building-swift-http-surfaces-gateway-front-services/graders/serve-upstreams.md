---
type: llm
focus: { source: file, path: acme-api/Sources/Acme/Serve/Serve.swift }
---

PASS if all of these hold:
- Serve creates one long-lived `GRPCClient` per upstream (users and catalog), not one per request.
- Each client's interceptor pipeline applies `BearerPropagationInterceptor<UserIdentity>` to that upstream's `<Entity>Service` descriptor (for example `.apply(propagation, to: .services([Acme_Users_V1_UserService.descriptor]))`), not per call and not to every service.
- Each client is wrapped in its generated stub (for example `Acme_Users_V1_UserService.Client(wrapping:)`), and both clients and the HTTP application run in one `ServiceGroup`.

FAIL if propagation is applied per call or to all services, a client is created per request, or a client is missing from the `ServiceGroup`.
Grade only against these criteria; do not fail for issues they do not mention.
