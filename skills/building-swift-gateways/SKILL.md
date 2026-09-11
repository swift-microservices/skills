---
name: building-swift-gateways
description: Builds or changes the HTTP surface in front of Swift services on Hummingbird or Vapor: a two-target gateway package, an OpenAPI document generating types only, a chain of request contexts, three router tiers with a bearer middleware, one controller per resource holding generated gRPC client protocols, throwing schema conversions, RFC 9457 problem details, and a composition root that propagates the caller's token to user-facing upstreams. Use when creating an API gateway or REST surface, adding or reshaping routes, translating HTTP to gRPC, choosing Hummingbird or Vapor for an edge service, or editing an openapi.yaml, request context, controller, or error middleware.
paths: "Sources/API/**/*.swift,Sources/API/openapi.yaml"
---

# Building Swift gateways

One way to put an HTTP surface in front of a gRPC system: a package that owns no data, identifies the caller once, and translates every request into an RPC and every reply and failure back. It encodes conventions learned from running such gateways on the [swift-microservices](https://github.com/swift-microservices) packages and an organization layer, `<project>-core`. Preserve every convention unless the user explicitly changes it; where the repository already has an established convention that differs, the repository wins for unrelated code.

The services behind the gateway, the boundaries between them, and how the gateway is deployed are separate skills; this one builds the gateway.

## Load the references

| Task | Read |
| --- | --- |
| Every task | [api-gateway.md](references/api-gateway.md) — targets, source tree, the OpenAPI document, contexts, tiers, routes, controllers, conversions, error translation, composition, the Vapor alternative |

Swift style, the identities, and the mTLS client factory are the building-swift-services skill's; load its swift-style, identity-and-access, and composition references when a task reaches them.

## Principles

1. **A gateway is not a service.** It owns no entities, repositories, or database, and makes no business decision; those live in the services it fronts.
2. **The OpenAPI document is the contract.** Types are generated from it; routes are registered by hand, so there is one routing mechanism.
3. **Identify once, require per route.** The bearer middleware binds a caller if a token is present; each tier states whether one is required, and no middleware carries a path exception.
4. **Authorization is a property of the method-and-resource pair.** Administrative access is a context conversion at the verb, never a path prefix.
5. **Translate, never collapse.** A conversion throws on a malformed upstream value, and an upstream status reaches the client as the mapped problem, not as 500.
6. **The caller travels unchanged.** The user's token is forwarded to user-facing upstreams by an interceptor on those descriptors alone; the gateway never mints or rewrites a credential.

## Rules

### Package and targets

1. Name the package `<organization>-api` with exactly two targets — `API` for the surface and `<Project>` for the composition root — and no Core, Postgres, or provider target. `API` links `Hummingbird`, `HummingbirdAuth`, `Authentication`, `AuthenticationHummingbird`, and `<Project>Authentication`; the executable adds `AuthenticationJWT`, `AuthenticationGRPC`, `JWTKit`, the gRPC transport, and one `<Service>Protos` product per upstream. Declare a package only when a target links one of its products.
2. Keep `openapi.yaml` beside `openapi-generator-config.yaml` in `Sources/API/`, generating `types` only with `package` access. Never reach for the document with a resource path that escapes the target.
3. Keep `@main`, `ConfigReader`, client construction, and logging bootstrap out of the `API` target.

### Contexts and tiers

4. Chain `BasicRequestContext` → `IdentityRequestContext` → `AdminRequestContext`. Carry `coreContext` across rather than rebuilding it, so path parameters survive. `IdentityRequestContext` holds `identity: UserIdentity?`; `AdminRequestContext` holds a non-optional identity and throws `401` when none is bound and `403` when the role is not `.admin`.
5. Register routes in three tiers: session-issuing and health routes outside any authenticating middleware; an identifying tier under `BearerAuthenticationMiddleware<IdentityRequestContext>(authenticator:)` that admits anonymous requests; a requiring tier under `IsAuthenticatedMiddleware`. Never a path exception inside a middleware, and never collapse the identifying and requiring tiers.
6. Give administrative routes the same path as the resource they act on, gated by `group(context: AdminRequestContext.self)` at the verb, never an `/admin` prefix. Where a check depends on a path parameter, write it in the handler under one name.
7. Keep verb-shaped routes verb-shaped: sessions, webhooks, and callbacks are workflows, not resources.

### Controllers and conversion

8. One `XController` per resource, holding generated client protocols — one per proto service it speaks — with registration methods named for the tier they mount into. The gateway never speaks an internal service.
9. Put conversions in `Schemas/Requests/` and `Schemas/Responses/` as `X+RPC.swift`. A conversion throws on a malformed upstream value; it never drops it with `compactMap`.
10. Keep an idempotency key the HTTP client cannot carry out of the request schema and mint one in the gateway conversion; expose it at HTTP only when the client genuinely retries with the same key.
11. Answer every failure as RFC 9457 problem details with `application/problem+json`. Map `RPCError` by code — `invalidArgument` 400, `unauthenticated` 401, `permissionDenied` 403, `notFound` 404, `alreadyExists` 409, `resourceExhausted` 429, `unimplemented` 501, `unavailable` 503, `deadlineExceeded` 504 — and reserve 500 for a failure the gateway itself cannot classify, logged with its cause.

### Composition

12. Follow the section order Configuration, Logging, Infrastructure, Composition, Router, Hummingbird, Lifecycle. Under Infrastructure build `JWTAuthenticator<UserIdentity>(publicKey:)` from the mounted public key by path, and one `GRPCClient` per upstream with a required host and port, the mTLS client factory, and `serviceConfig: .defaults`.
13. Apply `BearerPropagationInterceptor<UserIdentity>()` per client, to the upstream's user-service descriptors alone, so a public service is dialled with nothing. Under Composition wrap each client in one generated stub per proto service and hand the stubs to the controllers.
14. Own the application and every client in one `ServiceGroup` with graceful shutdown. Read the listener from `ApplicationConfiguration(reader:)` scoped to `http.server`. Publish no host port; the address comes from the ingress.
15. Default to one target, one document, and one application. Split into two applications only when administrative routes must not be publicly routable at all.

### Vapor

16. On Vapor 4, the middleware is swift-authentication-vapor's `BearerAuthenticationMiddleware` over an `Authenticatable` identity; the requiring tier is `guardMiddleware()`; the admin check is a route-group middleware. The principal is read from `request.serviceContext`, and outgoing gRPC calls run under `ServiceContext.withValue(req.serviceContext)`, because Vapor 4's responder chain does not carry a task-local to routes.

### Tests

17. Compose the application in tests exactly as `Serve` does, over mocked generated client protocols — one mock per proto service — and a real `JWTIssuer<UserIdentity>` and `JWTAuthenticator<UserIdentity>` over a throwaway Ed25519 key. Cover the tier matrix: anonymous → 401, a token whose subject is not a user id → 401, the user and admin paths, and each error translation.

## Workflow

Copy this checklist and check items off as you go:

```
Build a gateway:
- [ ] 1. Package: swift package init --type executable, reshape to API and <Project>, link only what each target imports
- [ ] 2. Contract: openapi.yaml and openapi-generator-config.yaml in Sources/API/, generating types with package access
- [ ] 3. Contexts and errors: IdentityRequestContext, AdminRequestContext, ErrorMiddleware, the Problem types and their RPCError and HTTPError conformances
- [ ] 4. Controllers: one per resource over generated client protocols, registration methods named for their tier
- [ ] 5. Conversions: Schemas/Requests and Schemas/Responses as X+RPC.swift, throwing on a malformed upstream value
- [ ] 6. Serve: the authenticator from the public key, one GRPCClient per upstream with mTLS and the propagating interceptor on user-service descriptors, one stub per proto service, the three tiers, the application, one ServiceGroup
- [ ] 7. swift build, then exercise the tiers: a session-issuing route reaches its handler carrying an unverifiable bearer token, and a protected route carrying the same token is refused
```

For a focused change — one route, one conversion — load the reference's matching section and preserve the established tiers.

## Completion gates

Do not call work complete until every applicable gate passes.

- Exactly two targets, no database, the OpenAPI document beside its generator configuration in the generating target, types only.
- Child contexts carry `coreContext` across and a route declared with a path parameter can read it.
- Session-issuing routes are outside the authenticating middleware; the identifying tier admits anonymous requests; the requiring tier refuses them; no middleware holds a path exception.
- Administrative routes share the resource path and are reachable only through `AdminRequestContext`; absent is 401 and insufficient is 403.
- One generated stub per proto service, and `BearerPropagationInterceptor<UserIdentity>` on the user-service descriptors alone.
- Every upstream failure reaches the client as problem details with the mapped status; a malformed upstream value is an error, never a shorter list.
- The application and every client are in one `ServiceGroup`; no host port is published.
- A session-issuing route reaches its handler while carrying an unverifiable bearer token, and a protected route carrying the same token is refused.

If a gate requires an unresolved product or security decision, stop at the safe boundary and request that decision rather than inventing behavior.
