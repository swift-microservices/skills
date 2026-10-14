---
name: reviewing-swift-services
description: Reviews an existing Swift service, monolith, or HTTP gateway package against the swift-microservices conventions and reports findings with file-and-line evidence, read-only. Audits the package and targets, Swift settings and Foundation use, Core use cases, Postgres roles and tenant policies, proto contracts and status mapping, the HTTP surface and its tiers, identities and interceptors, the composition root, tests, and delivery. Invoked by the user with /swift-microservices:reviewing-swift-services [path]. Use when the user asks for a review or audit of a Swift service against the conventions.
context: fork
agent: Explore
background: false
disable-model-invocation: true
allowed-tools: Read Grep Glob Bash(swift build *) Bash(swift test *) Bash(git *)
argument-hint: [path]
---

# Reviewing Swift services

An audit of one application package against the rules of the writing-swift-server-code, building-swift-services, building-swift-http-surfaces, orchestrating-temporal-workflows, and delivering-swift-services skills. It reads, greps, builds, and tests; it changes nothing. Do not edit, write, move, or delete a file, and do not run a formatter. If a fix is obvious, describe it in the finding.

Read applicable `AGENTS.md` files first: their project profile, styles, and recorded exceptions override these conventions. Where a rule says *default* and names an alternative, that is a project choice: the decision record decides it, and a recorded choice is not a finding. Each check below names the rule; the linked reference holds its detail — open it when a check is in doubt rather than ruling from memory.

## Locate the package

The package is `$ARGUMENTS` when given, otherwise the current directory. Confirm its shape: a service (`<Service>Core`, `<Service>Postgres`, `<Service>GRPC` or `<Service>HTTP`, `<Service>`); a monolith (the same targets per module, `<Project>HTTP` when it serves HTTP, one `<Project>` executable); or a gateway (`API` and `<Project>`). Otherwise report that it is not a service, monolith, or gateway package and stop; a reusable library is audited against the building-swift-server-libraries skill's completion gates instead, and say so. In a monolith read `<Service>` as each module. In a gateway, sections 2, 3, and the database parts of 7 are not applicable, and section 8 reads `Tests/APITests`.

Read `Package.swift` in full first, then `Sources/<Service>/Serve/Serve.swift` (`Sources/<Project>/…` in a monolith or gateway) and, except in a gateway, `Database/Migrations.swift` beside it. Open anything else only when a check names it.

## What a finding is

A finding is a claim you can point at: a file and line, a symbol, or a grep result, and the rule it violates. Never report a suspicion as a finding. A check that depends on a product decision or on data the repository does not show goes under **Decisions for the user**. Absence is evidence once the directory has been read: "no `CreateServiceRole` migration exists".

Severity, in this order:

- **Blocking** — data isolation, authorization, credentials, or build correctness: a policy that admits the wrong rows, resource or business authorization outside a use case (an additional JWT-role route gate without database lookups is allowed), a shared secret, a Core target linking a driver or server framework, a package that does not build.
- **Major** — a convention the architecture depends on: ownership, idempotency, the handler requirement and role per kind of caller, the transaction boundary, the roles.
- **Minor** — naming, layout, logging, test coverage gaps.

## Audit

Copy this checklist and check items off as you complete them:

```
Review progress:
- [ ] 1. Package and targets
- [ ] 2. Core
- [ ] 3. Persistence
- [ ] 4. Contracts and gRPC transport
- [ ] 5. HTTP surface
- [ ] 6. Identity and access
- [ ] 7. Composition
- [ ] 8. Tests
- [ ] 9. Delivery
- [ ] 10. Report
```

**1. Package and targets** — read `Package.swift`; rules in [architecture.md](../building-swift-services/references/architecture.md) and [service-package.md](../building-swift-services/references/service-package.md).
- Targets follow the module grammar: Core, Postgres, the transport targets the shape serves, the executable, `<Service>Workflows` only with Temporal, one `<Service><Technology>` per provider SDK, `<Project>HTTP` in a monolith with HTTP. A monolith may keep `<Project>Authentication`, `<Project>Persistence`, `<Project>Testing`, and its protos in-package until a second package needs them; that is not a finding. Recorded module-name collision exceptions are allowed. `Domain`, `Application`, `Infrastructure`, `Adapters`, or `Mappings` targets are a finding.
- The executable is the one product. Organization packages are pinned by tagged URL; any `.package(path:` is a finding.
- The shared machinery (`Database`, `PostgresDatabase`, `PostgresScope`, `MockDatabase`, `PostgresClient.withClient`) comes from the baseline packages: `grep -rn "protocol Database\|struct PostgresDatabase\|protocol PostgresScope\|struct MockDatabase\|func withClient" Sources Tests` returns nothing.
- Each target declares only the products it imports, and every declared package is used by a target or is a command plugin the build uses.
- Foundation dependencies and traits follow [foundation.md](../writing-swift-server-code/references/foundation.md#dependency-traits-that-pull-in-foundation): inspect resolved versions and transitive trait activation; `swift-configuration` with `traits: []` (or only required traits), no unnecessary `FullFoundation`/`JSON` default, no `NIOFoundationCompat`. An upstream full-Foundation requirement (Vapor 4, PostgresNIO) is a documented constraint, not a defect. If upstream information is unavailable, report that limitation rather than claiming a version is latest.
- Core links `Persistence`, `<Project>Authentication`, and `Logging`, and never a driver, grpc-swift, protobuf, a logging backend, configuration, a provider SDK, or a server framework (`grep -rn "^import" Sources/<Service>Core`). A focused standards library such as WebAuthn is allowed in Core; infrastructure SDKs need adapters.
- Every owned target attaches the shared settings array and the package is in Swift 6 mode with nonisolated default isolation, per [swift-settings.md](../writing-swift-server-code/references/swift-settings.md). A declared but unattached array is a finding; settings do not propagate.
- Run `swift build`; report the first diagnostic, distinguishing a source failure from unavailable dependencies or a toolchain mismatch. Never claim an unperformed build passed.

**2. Core** — read `Sources/<Service>Core`; rules in [core.md](../building-swift-services/references/core.md).
- Production code follows [foundation.md](../writing-swift-server-code/references/foundation.md#modern-apis): the conditional FoundationEssentials import, `FormatStyle`/`ParseStrategy` rather than `DateFormatter`, `ISO8601DateFormatter`, `NumberFormatter`, or `String(format:)`. An unconditional `import FoundationEssentials` in a package declaring an Apple platform is a finding; the conditional `Foundation` fallback is not.
- Entities and commands are immutable `Sendable` structs; a create command carries no service-generated identifier or persistence-stamped date. A type is `Codable` only when something encodes it (`grep -rn "Codable\|Encodable\|Decodable" Sources/<Service>Core`).
- Each database-backed use case is generic over `DatabaseType` with `DatabaseType.Scope: XUseCaseScope`, exposes an `XUseCaseProtocol` with one `callAsFunction`, and uses typed throws. User use cases take `subject: UserIdentity`, deriving self-only resource IDs from it; public and internal ones take `input:`. Core reading `OperationContext` is a finding.
- Permission predicates and fixed invariants are guards before I/O throwing the use case's own error.
- Every SQL unit of work is `database.withTransaction` with no remote call inside, except the [bounded single-use-secret rotation read](../building-swift-services/references/core.md#database-boundary). Transaction callbacks are plain nonescaping, caller-isolated closures, neither `@Sendable` nor `@concurrent`.
- Every use case takes a `Logger` last and logs the domain event; the catch-all mapping to `.unknown` logs `String(reflecting: error)`.
- Concurrency is resolved, not silenced: `grep -rn "@unchecked Sendable\|DispatchSemaphore\|Task.detached" Sources`; an uncommented `@unchecked Sendable` is a finding. Judge isolation questions with the `swift-concurrency` skill ([AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill)).
- No `Date` or clock is injected into a use case; stored dates come from the database, and a use case that decides on time reads `Date.now`.
- With a `<Service>Workflows` target, audit it against [workflows.md](../orchestrating-temporal-workflows/references/workflows.md). An entity-lifetime workflow uses `.rejectDuplicate` or `.useExisting`; an event-triggered workflow (a provider webhook) keyed by the event id with `.allowDuplicateFailedOnly` and an execution timeout, re-fetching live state in an Activity, is not a finding.

**3. Persistence** — read `Sources/<Service>Postgres` and the migration list; rules in [persistence.md](../building-swift-services/references/persistence.md).
- Roles follow [the roles](../building-swift-services/references/persistence.md#the-roles): the serving process never connects as the owner; a tenant-scoped and an unscoped role exist with distinct secrets where tenant tables do. Role migrations usually come first; a role appended later, before the policies naming it, is not a finding; a role inserted before applied migrations, or a policy naming a role created after it, is. No `BYPASSRLS` (`grep -rn BYPASSRLS Sources`).
- Service-owned identifiers are database-generated (`uuidv7()` by default, `gen_random_uuid()` on an older instance); a command or request choosing one is a finding. Dates are nouns (`creation_date`, `creationDate`; `grep -rn "_at\b\|At:" Sources`).
- Every user-owned table has a tenant-isolation policy on `app.caller_user_id` in both `USING` and `WITH CHECK`, and the internal and worker roles their own `USING (true)` version ([row-level security](../building-swift-services/references/persistence.md#row-level-security)). A missing policy, a policy without `WITH CHECK`, or a predicate admitting other callers' rows is blocking. State a missing `WITH CHECK` as an explicitness defect, not as open cross-tenant writes: Postgres applies `USING` to new rows. A package with no user-owned tables has no policies and one service role; recorded, that is not a finding.
- One scope type per database role, each conforming to the use-case scopes it admits.
- Statements are `PostgresPreparedStatement` values in `Statements/<Entity>`. Repositories translate known SQLSTATEs on named constraints into `XRepositoryError` and let unknown causes propagate; Core never matches on `PSQLError`. Collapsing every failure into a known case is a finding.
- A retryable create has a database-enforced idempotency key (`ON CONFLICT`); a state transition is guarded in `WHERE`.
- Migrations are named for their result, one create per table, unqualified table names. A service-named schema is a finding unless the decision record chose a schema per service.

**4. Contracts and gRPC transport** — read `Sources/<Service>GRPC` and the proto dependency; skip without gRPC. Rules in [grpc-and-protos.md](../building-swift-services/references/grpc-and-protos.md) and [identity-and-access.md](../building-swift-services/references/identity-and-access.md#two-rpc-services).
- Protos have [one home](../building-swift-services/references/grpc-and-protos.md#canonical-proto-package): `<project>-protos` by tag in microservices, in-package in a gRPC monolith. A `.proto` duplicated in a second package is a finding. The generator configuration sets `accessLevelOnImports: true`; its absence is a finding under `InternalImportsByDefault`.
- The contract has `<Entity>Service`, its RPCs and handlers grouped by caller, each handler starting with nothing, `requireUser()`, or `requireAdministrator()`, and `<Entity>InternalService` only when another process calls in, admitted by mTLS alone. Findings: a caller's-own request naming a user; a caller's-own use case on the internal role, or an administrator's on the tenant role where tenant tables exist; a `<Entity>Service` handler calling an internal use case; an RPC and use case nothing calls.
- Conversions are `X+Protobuf.swift` initializers on the destination; transport validation happens there; `.unspecified` and `.UNRECOGNIZED` are refused, not defaulted. Typed failures map to stable codes; UUIDs are lowercased on the wire; generated messages appear only in this target and consumer adapters.
- Stored generated clients are `any <Package>_<Service>.ClientProtocol`; a bare `ClientProtocol` existential is a finding (`ExistentialAny`).

**5. HTTP surface** — read each `<Module>HTTP`, `<Project>HTTP`, or a gateway's `API`, and the router section of the root; skip without HTTP. Rules in [surface.md](../building-swift-http-surfaces/references/surface.md) and [gateway.md](../building-swift-http-surfaces/references/gateway.md).
- One `openapi.yaml` beside its generator config in each serving target, `package` access, one routing mechanism. A document reached through `resources:`, both mechanisms at once, or generated types in Core is a finding.
- `IdentityRequestContext` and `AdminRequestContext` carry `coreContext` across; `.init(source:)` loses path parameters. `AdminRequestContext` throws 401 without identity and 403 for a non-administrator.
- Three tiers: session-issuing and health routes outside the bearer middleware; the identifying tier with `BearerAuthenticationMiddleware`, then `UserSettingsMiddleware` where tenant tables exist (never in a gateway); the requiring tier under `IsAuthenticatedMiddleware`. A refresh or sign-in route behind the bearer middleware is blocking.
- Administrative routes sit at the resource's path behind `AdminRequestContext`; a route serving both the caller's own record and any record by id, or a gateway handler with its own resource check, is a finding.
- Schema conversions throw on malformed values; `compactMap` over upstream or stored records is a finding. Every failure is `application/problem+json`. A gateway maps `RPCError` by code, `cancelled` to 499; collapsing every RPC failure to 500 is a finding.
- A gateway has exactly `API` and `<Project>`, no persistence, one mTLS `GRPCClient` per upstream in the `ServiceGroup`, bearer propagation only on `<Entity>Service` descriptors, no route to an internal descriptor, and no published host port.

**6. Identity and access** — read the root and the manifest; rules in [identity-and-access.md](../building-swift-services/references/identity-and-access.md).
- `UserIdentity` is the one `JWTPayload`, `sub` as a `UUID`, expiry verified. Verification uses `JWTAuthenticator<UserIdentity>` over the public key; only the authenticating service builds `JWTIssuer` over the private key. A symmetric secret shared between processes, a signing key outside the authenticating service, or a key read from an environment variable rather than a path is blocking; a symmetric key inside a single-process monolith is not a finding.
- `BearerAuthenticationInterceptor`, then `UserSettingsInterceptor` where tenant tables exist, on every `<Entity>Service` descriptor and neither on an internal one. A public RPC's own proof (a refresh token, a webhook signature) travels in the message.
- Outgoing clients carry `BearerPropagationInterceptor<UserIdentity>` on `<Entity>Service` descriptors alone; a client speaking as the process carries no interceptor and no token.
- No custom `@TaskLocal` carries a caller. Internal connections and listeners use mTLS with explicit CA trust, required client certificates, and server hostname verification; an internal listener without required client certificates is blocking. A client-facing listener (the gateway, or a monolith apps call directly through the edge) is server TLS with no client certificate and carries only `<Entity>Service`; that is not a finding, but plaintext or an internal descriptor on it is.

**7. Composition** — read the root and `Configuration/`; rules in [composition.md](../building-swift-services/references/composition.md) and [configuration.md](../building-swift-services/references/configuration.md).
- `// MARK:` sections in the order Configuration, Logging, Infrastructure, Composition, the transport sections, Lifecycle.
- `serve` is the default subcommand and migrations run before serving: `serve --migrate-database`, a `migrate` one-shot before the rollout, or a recorded advisory-locked apply. An unguarded concurrent migrate path, or none, is a finding. A Temporal worker is `worker run` on the same executable, per [worker.md](../orchestrating-temporal-workflows/references/worker.md).
- Configuration uses native readers, environment overrides before application defaults, no default or path argument beside a reader, policy defaults from Core's `.standard`, failing security overrides, and validation outside composition roots.
- Key material is configured by path; `TimedCertificateReloader` is primed before transport construction, passed to the [transport security factories](../building-swift-services/references/composition.md#transport-security-factories), and owned once in the `ServiceGroup`; Temporal has its own pair and reloader.
- One `PostgresClient` per role; one `PostgresDatabase` per module per role; a comment says which database each use case runs on.
- Logging is bootstrapped inline with the service label and identity metadata providers; every owned client, server, and worker is in one `ServiceGroup` with graceful shutdown.

**8. Tests** — read `Tests/<Service>CoreTests`, `Tests/<Service>WorkflowsTests` with Workflows, and the transport tests; rules in [testing.md](../building-swift-services/references/testing.md) and [surface.md](../building-swift-http-surfaces/references/surface.md#tests).
- swift-testing only, no `@testable`, no XCTest; mocks are actors, the database comes from a scoped `withDatabase` over `MockDatabase`, subjects from `makeSubject(role:)`, dates fixed except relative to `Date.now` in a time-decision test.
- Tests cover distinct business decisions, success contracts, error classifications, and authorization before I/O, with a call-count or fail-if-reached witness for no-I/O claims. Do not demand a test per enum case.
- Transport tests are both, split by purpose: router or handler tests over mocked use-case (or generated client) protocols for the tiers and error mapping, and one live loopback suite for token verification, descriptor-scoped propagation, and wiring, dialing each listener as its callers do (mTLS, or server TLS and a bearer). Missing either is a finding. A gateway's `APITests` also assert a caller's-own route sends no user id upstream.
- With Workflows, every Workflow runs on the time-skipping test server and replays recorded histories, per [testing.md](../orchestrating-temporal-workflows/references/testing.md); a branch no test reaches is a finding.
- Run `swift test`; a failure is blocking, quote it.

**9. Delivery** — read `.github/workflows`, the recorded image build, and `Package.resolved`; rules in [services-ci.md](../delivering-swift-services/references/services-ci.md) and [delivery.md](../delivering-swift-services/references/delivery.md).
- The executable commits `Package.resolved` and CI resolves from it. The image tool is the project's choice; with the static Linux SDK, CI keeps a static SDK build.
- Claims about avoiding full Foundation rest on [executable inspection](../delivering-swift-services/references/services-ci.md#release-image-and-foundation), not a static SDK build; a previously passing linking gate stays enabled.
- Every commit to a deployment branch publishes a SHA tag and the branch tag; the deploy step is mandatory. A pre-existing infrastructure failure is a decision, not a defect.
- Migrations run before serving from a short-lived owner client; serving clients never hold owner credentials.

## Report

Use exactly this shape.

```markdown
# Review of <package> at <commit>

## Findings

### Blocking
1. <one-sentence claim>. `<file>:<line>` — <rule, in a few words>.

### Major
…

### Minor
…

## Decisions for the user
- <a question the code cannot answer, and what depends on it>

## Passed
- <check> — <one-line evidence>
```

Order findings by severity, then by audit section. Report a section that does not apply to the package's shape as not applicable under **Passed**. Omit an empty severity heading. Every finding carries a file and line, or the exact grep that came back empty. **Passed** lists the checks that held, one line each. If `swift build` or `swift test` was not run, say why.
