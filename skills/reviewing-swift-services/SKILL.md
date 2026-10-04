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

An audit of one application package against the rules the writing-swift-server-code, building-swift-services, building-swift-http-surfaces, orchestrating-temporal-workflows, and delivering-swift-services skills state. It reads, greps, builds, and tests; it changes nothing. Do not edit, write, move, or delete a file, and do not run a formatter. If a fix is obvious, describe it in the finding and leave it to the user.

Read applicable `AGENTS.md` files first: their project profile, styles, and recorded exceptions override these general conventions. Preserve unrelated established code.

Rules in this skill are conventions the packages and the shared code shape depend on; keep them unless the user changes the vocabulary. Where a rule says *default* and names an alternative, that is a project choice: take the default unless the project's decision record says otherwise, and never switch it per file.

## Locate the package

The package is `$ARGUMENTS` when given, otherwise the current directory. Confirm it before auditing: a `Package.swift` whose targets follow `<Service>Core`, `<Service>Postgres`, `<Service>GRPC` or `<Service>HTTP`, `<Service>`; a monolith with the same targets per module and one `<Project>` executable; or an API gateway with `API` and `<Project>`. If none of these shapes is present, report that the directory is not a service, monolith, or gateway package and stop; a reusable library is audited against the building-swift-server-libraries skill's completion gates instead, and say so. In a monolith, read `<Service>` below as each module and the executable as `<Project>`. In a gateway, sections 2, 3, and the database parts of 6 do not apply; report them as not applicable rather than as findings.

Read `Package.swift` in full first, then `Sources/<Service>/Serve/Serve.swift` (`Sources/<Project>/Serve/Serve.swift` in a monolith or gateway) and, except in a gateway, `Sources/<Service>/Database/Migrations.swift`. Everything else is reached by the checks below; open a file only when a check names it.

## What a finding is

A finding is a claim you can point at: a file and a line, a symbol, or a grep result, and the rule it violates. Never report a suspicion as a finding. If a check cannot be decided from the code — a policy whose intent depends on a product decision, a migration whose rollback needs data the repository does not show — report it under **Decisions for the user**, not as a defect. Absence is evidence too: "no `CreateServiceRole` migration exists" is a finding once the migrations directory has been read.

Severity, in this order:

- **Blocking** — data isolation, authorization, credentials, or build correctness: a policy that admits the wrong rows, resource or business authorization delegated outside a use case (an additional JWT-role route gate without database lookups is allowed), a shared secret, a Core target linking a driver or a server framework, a package that does not build.
- **Major** — a convention whose violation the architecture depends on: ownership, idempotency, the interceptor and role per kind of caller, the transaction boundary, the roles.
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

**1. Package and targets** — read `Package.swift`.
- Targets are `<Service>Core`, `<Service>Postgres`, the transport targets the shape serves (`<Service>GRPC`, `<Service>HTTP`, or both), `<Service>`, plus `<Service>Workflows` only with Temporal and one `<Service><Technology>` per provider SDK. Evidence: the `targets:` array. Recorded module-name collision exceptions such as `AuthenticationRPC` / `AuthenticationServer` are allowed. Names such as `Domain`, `Application`, `Infrastructure`, `Adapters`, `Mappings` are a finding.
- The executable is the one product. Evidence: `products:`.
- Organization packages are pinned by tagged URL. Evidence: any `.package(path:` is a finding.
- Dependencies are the building skill's baseline packages and `<project>-core`, and `Database`, `PostgresDatabase`, `PostgresScope`, `MockDatabase`, and `PostgresClient.withClient` are used from them. Evidence: `Package.swift` against the baseline table, and `grep -rn "protocol Database\|struct PostgresDatabase\|protocol PostgresScope\|struct MockDatabase\|func withClient" Sources Tests` returning nothing.
- Every target declares only the products it imports, and every declared package is used by some target. Evidence: compare each target's `import` lines with its `dependencies:`.
- Audit Foundation dependencies against the writing-swift-server-code skill's [dependency and trait guidance](../writing-swift-server-code/references/foundation.md#dependency-traits-that-pull-in-foundation): inspect resolved versions and tagged manifests, including transitive trait activation. Check current compatible releases when upstream information is available; if it is unavailable, report that limitation instead of claiming an old version is latest. Check `swift-configuration` opts out of defaults with `traits: []` for environment-based configuration, or explicitly selects only required traits: its default `JSON` provider pulls full Foundation through `JSONSerialization`. Unnecessary `FullFoundation`/`JSON` defaults or a direct `NIOFoundationCompat` dependency where Essentials helpers suffice are findings. An upstream full-Foundation requirement, such as that of the audited Vapor 4 and PostgresNIO versions, is a documented constraint, not itself a defect.
- Focused standards/computation libraries such as WebAuthn may be used directly in Core when abstraction adds no useful seam, including their standard types and concrete engines. Infrastructure SDKs still require adapters.
- `<Service>Core` links `Persistence`, `<Project>Authentication`, and `Logging`, and never a driver, grpc-swift, protobuf, a logging backend, configuration, a provider SDK, or a server framework. Evidence: the Core target's `dependencies:` and `grep -rn "^import" Sources/<Service>Core`.
- `swiftLanguageModes: [.v6]` is set. Check every owned Swift library, executable/application, and test target receives the shared `ExistentialAny`, `MemberImportVisibility`, `InternalImportsByDefault`, and `NonisolatedNonsendingByDefault` settings, following the writing-swift-server-code skill's [Swift settings](../writing-swift-server-code/references/swift-settings.md). A declared array that is never attached is insufficient; dependency settings do not propagate. Inspect default isolation separately: a server must not gain blanket MainActor isolation. Confirm imports match package/public API access and member-providing modules are imported in the using file.
- Then run `swift build`; report the first diagnostic and distinguish a source failure from unavailable dependencies or a toolchain/SDK mismatch. Do not claim an unperformed build passed.

**2. Core** — read `Sources/<Service>Core`.
- Across all production targets, follow the writing-swift-server-code skill's [Foundation and modern API policy](../writing-swift-server-code/references/foundation.md#modern-apis): FoundationEssentials where needed, `FormatStyle`/`ParseStrategy` rather than `DateFormatter`, `ISO8601DateFormatter`, `NumberFormatter`, or `String(format:)`, and date parsing and JSON decoding matched to the wire contract. Evidence: imports and concrete API call sites, checking platform/toolchain availability. A supported SDK's conditional `import Foundation` fallback is not a violation. An unconditional `import FoundationEssentials` in a package that declares an Apple platform is a finding: the macOS SDK has no such module. Distinguish localized modern styles requiring internationalization from ISO 8601 APIs available in Essentials; an upstream full-Foundation dependency does not change what our code uses.
- Entities and commands are immutable `Sendable` structs; a create command carries no service-generated identifier and no persistence-stamped date. Evidence: `grep -rn "let id" Sources/<Service>Core/**/Commands`.
- A Core type is `Codable` only when something encodes it, usually the workflow state and result a workflow-client port returns. Evidence: `grep -rn "Codable\|Encodable\|Decodable" Sources/<Service>Core`; a conformance with no encoder, decoder, or Temporal port behind it is a finding.
- Each database-backed use case is generic over `DatabaseType` with `DatabaseType.Scope: XUseCaseScope`; every use case exposes an `XUseCaseProtocol` and uses typed throws. No-database operations need no artificial scope. Evidence: the use case's declaration line.
- User use cases take explicit `subject: UserIdentity` and business `input:` when needed, deriving self-only resource IDs from the subject; public and internal operations take `input:`. Core reading `ServiceContext` or requiring an application process principal is a finding.
- Explicit permission predicates are guards before I/O throwing the use case's own `.forbidden`; a self-only operation deriving its resource ID from `subject` needs no redundant equality guard. Fixed invariants are guards before I/O. A focused standards engine or policy value is allowed as a concrete initializer parameter; substitutable collaborators use protocols.
- Every SQL unit of work is `database.withTransaction`; no remote call inside it except the [bounded single-use-secret rotation read](../building-swift-services/references/core.md#database-boundary). Nontransactional-store or no-database operations do not need an artificial database dependency. Evidence: grep for client calls inside a `withTransaction` closure.
- Every use case takes a `Logger` as its last initializer parameter and logs the domain event; the catch-all that maps to `.unknown` logs `String(reflecting: error)`. Evidence: the `catch {` block.
- Transaction callbacks are plain nonescaping operations that preserve caller isolation, with neither `@Sendable` nor `@concurrent`. Inspect protocol witnesses and shared test doubles; check actor reentrancy, scope lifetime, and rollback versus in-memory mutation separately.
- Concurrency is resolved rather than silenced: no `@unchecked Sendable` without a comment saying what makes it safe, no semaphore or ad-hoc lock inside an async context, concurrency structured rather than detached, so every task lives in a task group or in the `ServiceGroup` and cancellation reaches every worker loop and stream. Evidence: `grep -rn "@unchecked Sendable\|DispatchSemaphore\|Task.detached" Sources`. Judging an isolation question is the `swift-concurrency` skill's ([AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill)); load it rather than ruling from the diagnostic.
- No `Date()`, clock, or `now` closure is injected to stamp a record; a `Clock` injected where a use case decides on time (an expiry, a grace period) is the allowed alternative, not a finding.

**3. Persistence** — read `Sources/<Service>Postgres` and the migration list.
- The role migrations precede every table, and the serving process never connects as the owner: by default `CreateServiceRole` first, then `CreateInternalRole` on a tenant service and `CreateWorkerRole` with a worker; other names are a project choice, not a finding, provided a tenant-scoped role and an unscoped role are distinct with distinct secrets. No role has `BYPASSRLS` (`grep -rn BYPASSRLS Sources`).
- Every service-owned identifier is database-generated; externally assigned standard/provider identifiers are validated and preserved. For service-generated UUIDs use `UUID PRIMARY KEY DEFAULT uuidv7()` by default or `gen_random_uuid()` on an older instance; a create command or request choosing a service-generated id is a finding. Dates are nouns (`creation_date`, not `created_at`; `creationDate`, not `createdAt`). Evidence: `grep -rn "_at\b\|At:" Sources`.
- Every table whose rows belong to users has a tenant-isolation policy on `app.caller_user_id`, in both `USING` and `WITH CHECK`, and the internal and worker roles get their own `TO "<role>" USING (true)` version. Evidence: `grep -rn "CREATE POLICY" -A 3 Sources/<Service>Postgres/Migrations`. A tenant table with no policy, a policy without `WITH CHECK`, or a predicate that admits rows beyond the caller's own, is blocking. (Without `WITH CHECK`, Postgres applies the `USING` expression to new rows, so the policy is not open today; it is blocking because the write predicate must be explicit and survive a later edit to `USING`. State it that way rather than claiming cross-tenant writes.) A package with no user-owned tables (a single-tenant application, an internal tool) has no policies, one service role, and no settings interceptor or middleware; that is not a finding when the README or decision record says so, and an advisory to record it when nothing does.
- One scope type per database role, each conforming to `PostgresScope` and to the use-case scopes it admits. Evidence: `Sources/<Service>Postgres/Scopes`.
- Statements are `PostgresPreparedStatement` values in `Statements/<Entity>`; repositories translate `PSQLError` and SQLSTATE into `XRepositoryError`, naming the constraint that exists. A `PSQLError` reaching Core is a finding.
- A retryable create has a unique idempotency key enforced by the database with `ON CONFLICT`, and a state transition is guarded in `WHERE`. Evidence: the statement SQL.
- Migrations are named for their result, one create per table, unqualified table names, no service-named schema.

**4. Contracts and gRPC transport** — read `Sources/<Service>GRPC` and the proto dependency; skip when the package serves no gRPC.
- Canonical protos have one home: `<project>-protos` by tag in microservices, with no `.proto` in a service; `Sources/<Module>GRPC/Protos/` with the generator plugin in a gRPC monolith. A `.proto` duplicated in a second package is a finding.
- The contract is split by caller: `<Entity>PublicService`, `<Entity>Service`, `<Entity>AdminService`, `<Entity>InternalService`, one conformance each at the feature root, holding only that caller's use cases. A `…Service` request that names a user, or an administrative RPC on `…Service`, is a finding; so is a `…Service` use case on the internal role or an `…AdminService` one on the tenant-scoped role.
- Conversions live in the feature's `Protobuf/` directory as `X+Protobuf.swift`, as initializers on the destination type or inline construction in the one method that needs it; transport validation (UUID parsing, enum recognition) happens in the conversion initializer; `.unspecified` and `.UNRECOGNIZED` are refused, not defaulted. Evidence: each `X+Protobuf.swift` declares initializers on the destination type.
- User handlers require the verified user, then call the owning use case. Internal handlers accept business input directly behind mTLS. Map typed failures to stable gRPC codes. User permission checks belong in use cases; business invariants apply to every audience.
- UUIDs are lowercased on the wire. Generated messages appear only in this target and consumer adapters.

**5. HTTP surface** — read each `<Module>HTTP`, `<Project>HTTP`, or a gateway's `API`, and the Router section of `Serve.swift` (`API`'s router builder in a gateway); skip when the package serves no HTTP. Judge against the building-swift-http-surfaces skill.
- One `openapi.yaml` beside `openapi-generator-config.yaml` in each target that serves it, generating with `package` access, and one routing mechanism: hand-registered routes over generated types by default, or generated server stubs throughout when the project chose them. A document outside its target reached through `resources:`, or both mechanisms at once, is a finding. Generated types in Core are a finding.
- `IdentityRequestContext` and `AdminRequestContext` carry `coreContext` across; a child context rebuilt with `.init(source:)` loses path parameters and is a finding. `AdminRequestContext` throws 401 for no identity and 403 for a non-administrator.
- Three tiers: session-issuing and health routes outside the bearer middleware; an identifying tier with `BearerAuthenticationMiddleware`, then `UserSettingsMiddleware` wherever tenant tables exist (never in a gateway); a requiring tier under `IsAuthenticatedMiddleware`. A refresh or sign-in route behind the bearer middleware is blocking, because an expired access token then locks the caller out. Evidence: the `Router` section and each controller's registration methods.
- Administrative routes at the resource's path behind `AdminRequestContext`; the gate reads only verified JWT roles, and the use case still decides (a gateway's handler-level path-parameter check is the exception the skill names).
- Conversions in `Schemas/Requests/` and `Schemas/Responses/` throw on malformed values; `compactMap` over upstream or stored records is a finding. Every failure is `application/problem+json`; a gateway maps `RPCError` by code, and collapsing every RPC failure to 500 is a finding.
- A gateway has exactly `API` and `<Project>`, no persistence package, one mTLS `GRPCClient` per upstream in the `ServiceGroup`, `BearerPropagationInterceptor<UserIdentity>` only on user-service descriptors, no route to an internal descriptor, and no published host port.

**6. Identity and access** — read `Serve.swift` and the manifest.
- `UserIdentity` is the one `JWTPayload` type, keys `sub` as a `UUID`, and verifies expiry in `verify(using:)`; additional claims are stored properties on it. Verification uses `JWTAuthenticator<UserIdentity>` over the public key (the `<Project>Authentication` `init(publicKey:)` convenience, or `init(keys:)` over a collection holding only public keys); only the authenticating service builds `JWTIssuer<UserIdentity>` over the private key. A symmetric secret shared between processes, a JWT signing key outside the authenticating service, or a key read from an environment variable rather than a path, is blocking; a symmetric key inside a single-process monolith is not a finding.
- Apply `BearerAuthenticationInterceptor` and then tenant `UserSettingsInterceptor` only to user descriptors. Internal descriptors rely on listener mTLS, not an application authentication interceptor. Keep public proof-checking paths separate from user bearer authentication.
- Outgoing clients carry `BearerPropagationInterceptor<UserIdentity>` on user-service descriptors alone; a client that speaks as the process carries no interceptor and no token.
- No custom `@TaskLocal` carries a caller. Logging includes the local process label and verified-user metadata, not an invented remote process identity.
- Internal service connections use transport mTLS with explicit CA trust. Check private listener exposure, required client certificates, server hostname verification, and the absence of internal gateway routes.

**7. Composition** — read `Serve.swift` and `Configuration/`.
- `// MARK:` sections in the order Configuration, Logging, Infrastructure, Composition, then Router and Hummingbird with HTTP and gRPC with gRPC, then Lifecycle; a worker's `Run` has Worker in place of the transport sections.
- `serve` is the default subcommand, and migrations run before serving: `serve --migrate-database` by default, or a `migrate` subcommand used as a one-shot job before the rollout; a migrate path the serving container also runs unguarded, or no migration path at all, is a finding. A Temporal worker is `worker run` on the same executable with its own composition root.
- Configuration uses native readers where available and executable-local relative-key extensions otherwise. Environment overrides precede application defaults; deployment defaults have one application owner, subject to recorded project exceptions. Policy defaults derive from Core's `.standard`, and malformed security overrides fail. No default/path arguments are passed beside a reader. Numeric application duration keys expose their units; upstream keys retain their names. Validation stays outside composition roots.
- Key material is configured by path. Prime `TimedCertificateReloader` from `NIOCertificateReloading` before transport construction; pass it to scoped mTLS factories and own it once in `ServiceGroup`. Temporal has a distinct pair, scope, and reloader. Verify renewal on fresh handshakes and trust-root restart behavior.
- One `PostgresClient` per role; one `PostgresDatabase` per database built with `PostgresDatabase(client:logger:)`; a comment says which database each use case runs on.
- Logging is bootstrapped inline with the service name as label and the identity metadata providers, shipping structured logs to one aggregator: stdout plus in-process shipping by default, or stdout alone where the platform collects it; every owned runnable client, server, and worker is in one `ServiceGroup` with graceful shutdown. A borrowed SDK-managed HTTP singleton is allowed as a recorded lifecycle exception; its requests still belong to the owning RPC or Activity.

**8. Tests** — read `Tests/<Service>CoreTests`, and `Tests/<Service>WorkflowsTests` where the service has Workflows.
- The target depends on Core, `Logging`, `<Project>Authentication`, and `<Project>Testing`; it is swift-testing, with no `@testable` and no XCTest.
- Mocks are actors in `Mocks/`, the database is built through a scoped `withDatabase` helper over `MockDatabase`, subjects come from `makeSubject(role:)`, dates are fixed.
- Tests cover distinct business decisions, success contracts, meaningful error classifications, and authorization before I/O. Require a call-count or fail-if-reached witness for no-I/O claims. Identify missing behavior, redundant implementation checks, or mock-only guarantees; do not impose a test per enum case or overload.
- Core use-case tests do not bind `ServiceContext`. Prefer the router harness for credential/role refusals; live transports prove descriptor-scoped propagation, receiver verification, wire conversion, and lifecycle. Generic TLS admission/renewal can live once in a shared contract suite per the project profile. Fixture-only configuration is not production-wiring evidence.
- With a `<Service>Workflows` target, `<Service>WorkflowsTests` runs every Workflow on the time-skipping test server in `.serialized` suites, covers each branch and one non-retryable failure, and replays recorded histories. A Workflow with no end-to-end test, a branch no test reaches, or a suite that round-trips payloads by hand instead is a finding. Evidence: `grep -rn "temporalTimeSkippingTestServer\|WorkflowReplayer" Tests`.
- Then run `swift test`; a failure is blocking, quote it.

**9. Delivery** — read `.github/workflows`, the Containerfile, and `Package.resolved`.
- The executable commits `Package.resolved`; CI resolves from it. The image is built for the deployment architecture with the static Linux SDK.
- Claims about avoiding full Foundation have separate Linux evidence: [library consumer linking](../delivering-swift-services/references/library-ci.md#capability-exceptions) or [service executable inspection](../delivering-swift-services/references/services-ci.md#release-image-and-foundation). A successful static SDK build is insufficient evidence. Check that a previously passing linking gate remains enabled, and that any unavoidable upstream requirement is recorded with its resolved version rather than presented as an Essentials-only graph.
- Every commit to a deployment branch publishes a SHA tag and the branch tag; the deploy step is mandatory, not skipped on a missing secret. A pre-existing infrastructure failure, such as a runner the account cannot bill, is reported as a decision, not a defect of the service.
- Migrations run before serving, with `serve --migrate-database` at boot or a `migrate` one-shot ordered before the rollout, from a short-lived owner client; the serving clients never hold owner credentials.

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

Order findings by severity, then by the audit section they came from. Report a section that does not apply to the package's shape as not applicable under **Passed**. Omit an empty severity heading. Every finding carries a file and line, or the exact grep that came back empty. "Passed" lists the checks that held, one line each, so the user can see what was looked at and not only what was wrong. If `swift build` or `swift test` was not run, say why.
