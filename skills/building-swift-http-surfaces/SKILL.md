---
name: building-swift-http-surfaces
description: Builds or changes the HTTP surface of a Swift server the swift-microservices way, on Hummingbird by default or Vapor 4. A module's <Module>HTTP target over its use cases in a monolith or service, or an <organization>-api gateway package over generated gRPC clients in front of services. One OpenAPI document per surface generating types, request contexts, three router tiers with bearer and tenant-settings middleware, administrative routes behind AdminRequestContext, one controller per resource, throwing schema conversions, RFC 9457 problem details, RPCError mapping, upstream mTLS clients with bearer propagation, and router-harness tests. Use when adding or changing routes, controllers, middleware, request contexts, an openapi.yaml, problem details, or a gateway, or when putting HTTP in front of a Swift monolith or gRPC services.
paths: "Sources/**/openapi.yaml,Sources/*HTTP/**/*.swift,Sources/API/**/*.swift"
---

# Building Swift HTTP surfaces

One way to put HTTP on a system built with the building-swift-services skill: in a module, as its own `<Module>HTTP` target over the module's use cases, or in front of services, as a gateway package over their generated gRPC clients. The rules are the same for both; only the controller's collaborator differs. The package, Core, persistence, configuration, and the rest of the composition root are the building skill's — load it beside this one — and the Swift inside follows the writing-swift-server-code skill.

Read applicable `AGENTS.md` files first: their project profile, styles, and recorded exceptions override these general conventions. Preserve unrelated established code.

Rules in this skill are conventions the packages and the shared code shape depend on; keep them unless the user changes the vocabulary. Where a rule says *default* and names an alternative, that is a project choice: take the default unless the project's decision record says otherwise, and never switch it per file.

## Load the references

| Task | Read |
| --- | --- |
| Every task | [surface.md](references/surface.md) — where HTTP lives, the OpenAPI document, contexts, tiers, the tenant, route design, controllers, conversions, errors, the Router and Hummingbird sections, deployment, the Vapor alternative, tests |
| A gateway in front of services | [gateway.md](references/gateway.md) — the package, source tree, manifest, composition root, and tests |
| The module's use cases, the package manifest, configuration, identity, and the rest of the root | the building-swift-services skill |

## Principles

1. **A transport converts and identifies; the use case decides.** A route converts the request, identifies the caller, and calls a use case or an upstream; resource and business authorization stay in the owning use case.
2. **One routing mechanism, one contract.** The OpenAPI document in the target that serves it is the contract; routes are registered one way, chosen once per project.
3. **The tier a route is registered in decides what runs.** Identifying a caller and requiring one are separate decisions, made structurally by route groups, not by handler code or middleware order.
4. **A failure says what it is.** Every error is problem details with the status the classification earned; a malformed value is an error, never a silently shorter list.
5. **A surface is movable.** A module's HTTP target moves with the module; a gateway holds no data and no business rules, only conversions from one contract to another.

## Rules

1. Keep `openapi.yaml` beside `openapi-generator-config.yaml` in the HTTP target that serves it: one document per `<Module>HTTP` in a monolith, one in `<Service>HTTP`, one in a gateway's `API`. Default: generate `types` only with `accessModifier: package` and register routes by hand on the router. Alternative: generate `server` too and mount it through `OpenAPIHummingbird` or `OpenAPIVapor`, chosen once per project. Generated types never reach Core.
2. In a monolith, put the request contexts, the error middleware, and the problem types every `<Module>HTTP` shares in one hand-written `<Project>HTTP` target; a service's `<Service>HTTP` and a gateway's `API` hold their own. An `<Module>HTTP` links its module's Core, `Hummingbird`, `HummingbirdAuth`, `OpenAPIRuntime`, `<Project>Authentication`, and `Logging`; never Postgres or another module's targets.
3. Chain `BasicRequestContext` → `IdentityRequestContext` → `AdminRequestContext`, carrying `coreContext` across rather than rebuilding it with `.init(source:)`. `AdminRequestContext` holds a non-optional identity and throws 401 when none is bound and 403 when the role is not `.admin`.
4. Register routes in three tiers: session-issuing and health routes outside any authenticating middleware; an identifying tier under `BearerAuthenticationMiddleware<IdentityRequestContext>(authenticator:)` that admits anonymous requests, followed by `UserSettingsMiddleware` wherever a module has tenant tables; a requiring tier under `IsAuthenticatedMiddleware`, kept separate from the identifying tier. A gateway has no tenant middleware: the service that owns the rows binds the tenant from the forwarded token.
5. Give administrative routes the same path as the resource they act on, gated by `group(context: AdminRequestContext.self)` at the verb by default, or around a whole administrative route collection when requested. The gate checks verified JWT role claims without database lookups and supplements the use case's own check. Keep verb-shaped routes verb-shaped: sessions, webhooks, and callbacks are workflows, not resources.
6. One `XController` per resource, with registration methods named for the tier they mount into. In a module it holds the module's use-case protocols, passes `subject:` from the context or `input:` alone, and converts in `Schemas/Requests/` and `Schemas/Responses/` as `X+Schema.swift`; in a gateway it holds one generated client protocol per `<Entity>Service` and converts as `X+RPC.swift`. A conversion throws on a malformed value; it never drops one with `compactMap`.
7. Answer every failure as RFC 9457 problem details with `application/problem+json`. A module maps its use-case errors to statuses in the controller (invalid 400, absent caller 401, `.forbidden` 403, not found 404, duplicate 409, `.unknown` 500 logged with its cause); a gateway maps `RPCError` by code — `invalidArgument`, `failedPrecondition`, and `outOfRange` 400, `unauthenticated` 401, `permissionDenied` 403, `notFound` 404, `alreadyExists` and `aborted` 409, `resourceExhausted` 429, `unimplemented` 501, `unavailable` 503, `deadlineExceeded` 504 — and reserves 500 for a failure it cannot classify, logged with its cause.
8. Keep path prefixes in the composition root and routes in the controllers. Read the listener with `ApplicationConfiguration(reader:)` scoped to `http.server`, and own the application in the root's one `ServiceGroup`, beside the gRPC server when the process serves both.
9. A gateway is a package `<organization>-api` with exactly two targets, `API` and `<Project>`, no Core, Postgres, or persistence package. It builds `JWTAuthenticator<UserIdentity>` from the public key, one long-lived mTLS `GRPCClient` per upstream with `BearerPropagationInterceptor<UserIdentity>` on `<Entity>Service` descriptors alone, and one stub per `<Entity>Service`; it routes only `<Entity>Service` operations, never internal ones.
10. No HTTP process publishes a host port; its address comes from a sidecar or the platform ingress. Configure CORS only for browsers that reach the surface directly. Give every surface a health route in the first tier.
11. On Vapor 4, the middleware is swift-authentication-vapor's `BearerAuthenticationMiddleware` over an `Authenticatable` identity, the requiring tier is `guardMiddleware()`, the admin check is a route-group middleware, the principal is read from `request.serviceContext`, and use cases and outgoing calls run under `ServiceContext.withValue(req.serviceContext)`. A `<Module>HTTP` on Vapor is a `RouteCollection` per controller, and the Vapor form of `UserSettingsMiddleware` writes the tenant setting into `request.serviceContext`.
12. Test a surface by composing the application as `serve` does, over mocked use-case protocols (a module) or mocked generated client protocols (a gateway), with a real `JWTIssuer<UserIdentity>` and `JWTAuthenticator<UserIdentity>` over a throwaway key, driven by HummingbirdTesting's `.router` or `VaporTesting`. Cover the tier matrix, route-specific conversions, and distinct error mappings; test a shared mapping once; never re-assert a business rule through a mocked use case.

## Workflows

Copy the checklist that matches the task and check items off as you go.

```
Add the HTTP surface to a module or service:
- [ ] 1. <Module>HTTP (or <Service>HTTP): openapi.yaml and openapi-generator-config.yaml in the target, types only, package access
- [ ] 2. Contexts and errors in <Project>HTTP for a monolith, in the target itself for a service: IdentityRequestContext, AdminRequestContext, ErrorMiddleware, the Problem types and the use-case error conformances
- [ ] 3. Controllers: one per resource over the module's use-case protocols, registration methods named for their tier, X+Schema.swift conversions that throw
- [ ] 4. Root: the authenticator from the public key, the three tiers with BearerAuthenticationMiddleware, UserSettingsMiddleware where tenant tables exist, IsAuthenticatedMiddleware, every module's controllers mounted, ApplicationConfiguration(reader:), the application in the ServiceGroup
- [ ] 5. Tests over mocked use-case protocols: anonymous → 401, an unverifiable token → 401, the user and admin paths, distinct error mappings
```

```
Front services with a gateway:
- [ ] 1. Package: swift package init --type executable, reshape to API and <Project>, link only what each target imports
- [ ] 2. Contract: openapi.yaml and openapi-generator-config.yaml in Sources/API/, generating types with package access
- [ ] 3. Contexts and errors: IdentityRequestContext, AdminRequestContext, ErrorMiddleware, the Problem types and their RPCError and HTTPError conformances
- [ ] 4. Controllers: one per resource over generated client protocols, registration methods named for their tier, X+RPC.swift conversions that throw
- [ ] 5. Serve: the authenticator from the public key, one GRPCClient per upstream with mTLS and the propagating interceptor on `<Entity>Service` descriptors, one stub per `<Entity>Service`, the three tiers, the application, one ServiceGroup
- [ ] 6. APITests over one mocked client protocol per `<Entity>Service` and a throwaway-key JWTIssuer and JWTAuthenticator: a session-issuing route reaches its handler carrying an unverifiable bearer token, a protected route carrying the same token answers 401, a non-administrator gets 403, and RPCError codes map to their statuses
- [ ] 7. swift build and swift test
```

## Completion gates

Do not call work complete until every applicable gate passes.

- Each surface has one OpenAPI document in the target that serves it and one routing mechanism; generated OpenAPI types appear only in HTTP targets.
- Session-issuing and health routes sit outside the authenticating middleware; the identifying tier admits anonymous requests; the requiring tier refuses them; administrative routes are reachable only through `AdminRequestContext`; `UserSettingsMiddleware` follows the bearer middleware wherever tenant tables exist and nowhere in a gateway.
- Every failure is problem details with the classified status; no conversion drops a malformed value.
- Resource and business authorization stay in the use cases; a route gate reads only verified JWT role claims.
- A gateway declares no persistence package, routes no internal operation, forwards the original token only on `<Entity>Service` descriptors, and dials every upstream over mTLS from one long-lived client in its `ServiceGroup`.
- No HTTP process publishes a host port; the surface builds, and its router tests cover the tier matrix and the distinct error mappings.

If a gate requires an unresolved product, contract, or security decision, stop at the safe boundary and request that decision rather than inventing behavior.
