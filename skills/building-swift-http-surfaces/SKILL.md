---
name: building-swift-http-surfaces
description: Builds or changes the HTTP API of a Swift server the swift-microservices way, on Hummingbird by default or Vapor 4, and the Swift client SDK apps generate from it. Covers a module's HTTP target over its use cases, a gateway package over generated gRPC clients in front of services, one OpenAPI document per surface, request contexts, three router tiers with bearer and tenant-settings middleware, admin routes behind an admin context, one controller per resource, throwing conversions, RFC 9457 problem details, RPCError mapping, upstream mTLS clients with bearer propagation, router-harness and loopback tests, and a generated client SDK with token refresh. Use when adding or changing HTTP routes, controllers, middleware, request contexts, an openapi.yaml, problem details, or an API gateway, when putting HTTP in front of a Swift monolith or gRPC services, when building Vapor route collections or middleware, or when creating a Swift client SDK for iOS or macOS apps from an OpenAPI document.
paths: "Sources/**/openapi.yaml,Sources/**/openapi-generator-config.yaml,Sources/*HTTP/**/*.swift,Sources/API/**/*.swift,Sources/*SDK/**,Tests/APITests/**/*.swift"
---

# Building Swift HTTP surfaces

One way to put HTTP on a system built with the building-swift-services skill: in a module, as its own `<Module>HTTP` target over the module's use cases, or in front of services, as a gateway package over their generated gRPC clients. The rules are the same for both; only the controller's collaborator differs. The client SDK apps use is generated from the same document. The package, Core, persistence, configuration, and the rest of the composition root are the building skill's — load it beside this one — and the Swift inside follows the writing-swift-server-code skill.

Read applicable `AGENTS.md` files first: their project profile, styles, and recorded exceptions override these general conventions. Preserve unrelated established code.

Rules in this skill are conventions the packages and the shared code shape depend on; keep them unless the user changes the vocabulary. Where a rule says *default* and names an alternative, that is a project choice: take the default unless the project's decision record says otherwise, and never switch it per file.

## Load the references

| Task | Read |
| --- | --- |
| Every surface task | [surface.md](references/surface.md) — where HTTP lives, contexts, tiers, the tenant, route design, controllers, conversions, composition, deployment, tests |
| The OpenAPI document, its generator configuration, and the client contract it makes | [openapi-document.md](references/openapi-document.md) |
| Typed errors to problem details: the shared protocol, each error's mapping, the error middleware | [error-translation.md](references/error-translation.md) |
| A gateway in front of services | [gateway.md](references/gateway.md) — the package, source tree, manifest, router builder, composition root, router-harness and live loopback tests |
| A surface on Vapor 4 | [vapor.md](references/vapor.md) — identity and context, middleware, route collections, problem details, route groups, VaporTesting |
| A client SDK for apps | [client-sdk.md](references/client-sdk.md) — the package, the synced document, generator configuration, traits, `Problem`, token authentication, tests and CI |
| The module's use cases, the package manifest, configuration, identity, and the rest of the root | the building-swift-services skill: [service-package.md](../building-swift-services/references/service-package.md), [identity-and-access.md](../building-swift-services/references/identity-and-access.md), [persistence.md](../building-swift-services/references/persistence.md) for the tenant setting, [composition.md](../building-swift-services/references/composition.md), [transport-security.md](../building-swift-services/references/transport-security.md), and [testing.md](../building-swift-services/references/testing.md) |
| Foundation in conversions, problem details, and dates | the writing-swift-server-code skill's [foundation.md](../writing-swift-server-code/references/foundation.md) |
| The gateway's environment and address, or the SDK's CI | the delivering skill's [environment.md](../delivering-swift-services/references/environment.md) and [library-ci.md](../delivering-swift-services/references/library-ci.md) |

## Principles

1. **A transport converts and identifies; the use case decides.** A route converts the request, identifies the caller, and calls a use case or an upstream; resource and business authorization stay in the owning use case.
2. **One routing mechanism, one contract.** The OpenAPI document in the target that serves it is the contract for the server and every client; routes are registered one way, chosen once per project.
3. **The tier a route is registered in decides what runs.** Identifying a caller and requiring one are separate decisions, made structurally by route groups, not by handler code or middleware order.
4. **A failure says what it is.** Every error is problem details with the status the classification earned; a malformed value is an error, never a silently shorter list.
5. **A surface is movable.** A module's HTTP target moves with the module; a gateway holds no data and no business rules, only conversions from one contract to another.

## Rules

1. Keep `openapi.yaml` beside `openapi-generator-config.yaml` in the HTTP target that serves it: one document per `<Module>HTTP` in a monolith, one in `<Service>HTTP`, one in a gateway's `API`. Default: generate `types` only with `accessModifier: package` and `namingStrategy: idiomatic`, and register routes by hand. Alternative: generate `server` too and mount it through `OpenAPIHummingbird` or `OpenAPIVapor`, chosen once per project. Every operation has an `operationId`, a `security` entry matching its tier, and a `default` `application/problem+json` response over a declared `Problem` schema. Generated types never reach Core.
2. In a monolith, put the request contexts, the error middleware, and the problem types every `<Module>HTTP` shares in one hand-written `<Project>HTTP` target; a service's `<Service>HTTP` and a gateway's `API` hold their own. An `<Module>HTTP` links its module's Core, `Hummingbird`, `HummingbirdAuth`, `HTTPTypes`, `OpenAPIRuntime`, `<Project>Authentication`, and `Logging`; never Postgres or another module's targets.
3. Chain `BasicRequestContext` → `IdentityRequestContext` → `AdminRequestContext`, carrying `coreContext` across rather than rebuilding it with `.init(source:)`. `AdminRequestContext` holds a non-optional identity and throws 401 when none is bound and 403 when the role is not `.admin`.
4. Register routes in three tiers: session-issuing and health routes outside any authenticating middleware; an identifying tier under `BearerAuthenticationMiddleware<IdentityRequestContext>(authenticator:)` that admits anonymous requests, followed by `UserSettingsMiddleware` wherever a module has tenant tables; a requiring tier from `identified.group().add(middleware: IsAuthenticatedMiddleware())`, never added to the identifying group itself. A gateway has no tenant middleware: the service that owns the rows binds the tenant from the forwarded token.
5. Give administrative routes the same path as the resource they act on, gated by `group(context: AdminRequestContext.self)` at the verb by default, or around a whole administrative route collection when requested. The gate checks verified JWT role claims without database lookups and supplements the use case's own check. Keep verb-shaped routes verb-shaped: sessions, webhooks, and callbacks are workflows, not resources.
6. One `XController` per resource, with registration methods named for the tier they mount into, holding `any` protocol existentials. In a module it holds the module's use-case protocols, passes `subject:` from the context or `input:` alone, and converts in `Schemas/Requests/` and `Schemas/Responses/` as `X+Schema.swift`; in a gateway it holds one generated client protocol per `<Entity>Service` and converts as `X+RPC.swift`. Shared enum conversions go in `Schemas/Shared/`. A conversion throws on a malformed value; it never drops one with `compactMap`.
7. Answer every failure as RFC 9457 problem details with `application/problem+json` through `ErrorMiddleware` and `HTTPProblemResponse`. A module conforms each use-case error (invalid 400 and an idempotency key reused with different input 400, absent caller 401, `.forbidden` 403, not found 404, duplicate 409, `.unknown` 500); a gateway conforms `RPCError` by code — `invalidArgument`, `failedPrecondition`, and `outOfRange` 400, `unauthenticated` 401, `permissionDenied` 403, `notFound` 404, `alreadyExists` and `aborted` 409, `resourceExhausted` 429, `cancelled` 499, `unimplemented` 501, `unavailable` 503, `deadlineExceeded` 504 — and reserves 500 for a failure it cannot classify. Every 5xx is logged with its cause.
8. Keep path prefixes in the composition root or the router builder and routes in the controllers. Read the listener with `ApplicationConfiguration(reader:)` scoped to `http.server`, and own the application in the root's one `ServiceGroup`, beside the gRPC server when the process serves both.
9. A gateway is a package `<organization>-api` with exactly two targets, `API` and `<Project>`, no Core, Postgres, or persistence package. `API`'s `<Project>API` router builder takes a `Dependencies` value of `any …ClientProtocol` existentials and the authenticator. The executable builds `JWTAuthenticator<UserIdentity>` from the public key and one long-lived mTLS `GRPCClient` per upstream with `config: .gateway` keepalive and `BearerPropagationInterceptor<UserIdentity>` on `<Entity>Service` descriptors alone; the gateway routes only `<Entity>Service` operations, never internal ones.
10. No HTTP process publishes a host port; configure CORS only for browsers that reach the surface directly; give every surface a health route in the first tier.
11. On Vapor 4, follow [vapor.md](references/vapor.md): the identity from `req.auth.require(UserIdentity.self)`, the principal from `request.operationContext`, use cases and upstream calls under `OperationContext.withContext(req.operationContext)`.
12. Test a surface by composing the application as the root does, over mocked use-case protocols (a module) or mocked generated client protocols (a gateway, through `Dependencies.mocked`), with a real `JWTIssuer<UserIdentity>` and `JWTAuthenticator<UserIdentity>` over a throwaway key, driven by HummingbirdTesting's `.router` or `VaporTesting`. Cover the tier matrix, route-specific conversions, and distinct error mappings; test a shared mapping once; never re-assert a business rule through a mocked use case. A gateway adds one live loopback mTLS suite proving token propagation only on `<Entity>Service` descriptors, receiver verification, and the client wiring.
13. A client SDK is a library `<organization>-sdk` generated from a synced copy of the surface's document in its target (`generate: [types, client]`, `accessModifier: public`, `Problem` overridden onto a hand-written public type), with a default `OpenAPIURLSession` trait consumers can disable, and an `AuthenticationClient` that maps only a 401 to `.invalidCredentials` or `.invalidRefreshToken` and propagates every other error unchanged.

## Workflows

Copy the checklist that matches the task and check items off as you go.

```
Add the HTTP surface to a module or service:
- [ ] 1. <Module>HTTP (or <Service>HTTP): openapi.yaml as a client contract and openapi-generator-config.yaml in the target, types only, package access
- [ ] 2. Contexts and errors in <Project>HTTP for a monolith, in the target itself for a service: IdentityRequestContext, AdminRequestContext, ErrorMiddleware, Problem, HTTPProblemResponse, and the use-case error conformances
- [ ] 3. Controllers: one per resource over the module's use-case protocols, registration methods named for their tier, X+Schema.swift conversions that throw
- [ ] 4. Root: the authenticator from the public key, the three tiers with BearerAuthenticationMiddleware, UserSettingsMiddleware where tenant tables exist, IsAuthenticatedMiddleware, every module's controllers mounted, ApplicationConfiguration(reader:), the application in the ServiceGroup
- [ ] 5. Tests over mocked use-case protocols: anonymous → 401, an unverifiable token → 401, the user and admin paths, distinct error mappings
- [ ] 6. swift build and swift test
```

```
Front services with a gateway:
- [ ] 1. Package: swift package init --type executable, reshape to API and <Project>, link only what each target imports
- [ ] 2. Contract: openapi.yaml as a client contract and openapi-generator-config.yaml in Sources/API/, types with package access
- [ ] 3. Contexts and errors: IdentityRequestContext, AdminRequestContext, ErrorMiddleware, Problem, HTTPProblemResponse, the RPCError conformance
- [ ] 4. Controllers: one per resource over generated client protocols, registration methods named for their tier, X+RPC.swift conversions that throw
- [ ] 5. <Project>API: Dependencies of client existentials and the authenticator, addRoutes(to:) registering the three tiers
- [ ] 6. Serve: the authenticator, one GRPCClient per upstream with mTLS, config: .gateway, ServiceConfig.defaults, and propagation on <Entity>Service descriptors, one stub per <Entity>Service, the router, the application, one ServiceGroup
- [ ] 7. APITests: Dependencies.mocked over mocked client protocols, the tier matrix, conversions, RPCError codes to statuses, no internal routes; the live loopback mTLS suite
- [ ] 8. swift build and swift test
```

```
Build a client SDK:
- [ ] 1. Package <organization>-sdk: one <Project>SDK target, Apple platforms beside macOS, the OpenAPIURLSession default trait
- [ ] 2. The surface's openapi.yaml synced into Sources/<Project>SDK/, generator config types and client, public, Problem override
- [ ] 3. Problem, the AuthenticationResponse conformance, the AuthenticationClient with 401-only classification
- [ ] 4. <Project>Client: authenticated, anonymous, and ifAvailable generated clients by security; URLSession initializers under the trait
- [ ] 5. Consumer fixture in both trait configurations; runtime tests for the authentication client only
- [ ] 6. swift build, swift test when tests exist, and the consumer builds
```

## Completion gates

Do not call work complete until every applicable gate passes.

- Each surface has one OpenAPI document in the target that serves it and one routing mechanism; generated OpenAPI types appear only in HTTP targets; every operation declares its operation id, security, and problem response.
- Session-issuing and health routes sit outside the authenticating middleware; the identifying tier admits anonymous requests; the requiring tier refuses them; administrative routes are reachable only through `AdminRequestContext`; `UserSettingsMiddleware` follows the bearer middleware wherever tenant tables exist and nowhere in a gateway.
- Every failure is problem details with the classified status; no conversion drops a malformed value.
- Resource and business authorization stay in the use cases; a route gate reads only verified JWT role claims.
- A gateway declares no persistence package, routes no internal operation, forwards the original token only on `<Entity>Service` descriptors, and dials every upstream over mTLS from one long-lived client in its `ServiceGroup`.
- A client SDK reaches no document through `resources:`, builds with its default trait disabled, and never turns a transport or server failure into a credential rejection.
- No HTTP process publishes a host port; the surface builds, and its tests cover the tier matrix and the distinct error mappings.

If a gate requires an unresolved product, contract, or security decision, stop at the safe boundary and request that decision rather than inventing behavior.
