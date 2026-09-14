---
name: reviewing-swift-services
description: Reviews an existing Swift service package against the swift-microservices conventions and reports findings with file-and-line evidence, read-only. Audits the package and targets, Core use cases, Postgres roles and tenant policies, proto contracts and status mapping, identities and interceptors, the composition root, tests, and delivery. Invoked by the user with /swift-microservices:reviewing-swift-services [path]. Use when the user asks for a review or audit of a Swift service against the conventions.
context: fork
agent: Explore
background: false
disable-model-invocation: true
allowed-tools: Read Grep Glob Bash(swift build *) Bash(swift test *) Bash(git *)
argument-hint: [path]
---

# Reviewing Swift services

An audit of one service package against the rules the building, orchestrating, and delivering skills state. It reads, greps, builds, and tests; it changes nothing. Do not edit, write, move, or delete a file, and do not run a formatter. If a fix is obvious, describe it in the finding and leave it to the user.

Rules in this skill are conventions the packages and the shared code shape depend on; keep them unless the user changes the vocabulary. Where a rule says *default* and names an alternative, that is a project choice: take the default unless the project's decision record says otherwise, and never switch it per file.

## Locate the package

The package is `$ARGUMENTS` when given, otherwise the current directory. Confirm it before auditing: a `Package.swift` whose targets follow `<Service>Core`, `<Service>Postgres`, `<Service>GRPC` or `<Service>HTTP`, `<Service>`; a monolith with the same targets per module and one `<Project>` executable; or an API gateway with `API` and `<Project>`. If none of these shapes is present, report that the directory is not a service, monolith, or gateway package and stop. In a monolith, read `<Service>` below as each module and the executable as `<Project>`.

Read `Package.swift` in full first, then `Sources/<Service>/Serve/Serve.swift` and `Sources/<Service>/Database/Migrations.swift`. Everything else is reached by the checks below; open a file only when a check names it.

## What a finding is

A finding is a claim you can point at: a file and a line, a symbol, or a grep result, and the rule it violates. Never report a suspicion as a finding. If a check cannot be decided from the code — a policy whose intent depends on a product decision, a migration whose rollback needs data the repository does not show — report it under **Decisions for the user**, not as a defect. Absence is evidence too: "no `CreateServiceRole` migration exists" is a finding once the migrations directory has been read.

Severity, in this order:

- **Blocking** — data isolation, authorization, credentials, or build correctness: a policy that admits the wrong rows, authorization decided outside a use case, a shared secret, a Core target linking a driver or a server framework, a package that does not build.
- **Major** — a convention whose violation the architecture depends on: ownership, idempotency, the interceptor per audience, the transaction boundary, the roles.
- **Minor** — naming, layout, logging, test coverage gaps.

## Audit

Copy this checklist and check items off as you complete them:

```
Review progress:
- [ ] 1. Package and targets
- [ ] 2. Core
- [ ] 3. Persistence
- [ ] 4. Contracts and transport
- [ ] 5. Identity and access
- [ ] 6. Composition
- [ ] 7. Tests
- [ ] 8. Delivery
- [ ] 9. Report
```

**1. Package and targets** — read `Package.swift`.
- Targets are `<Service>Core`, `<Service>Postgres`, `<Service>GRPC`, `<Service>`, plus `<Service>Workflows` only with Temporal and one `<Service><Technology>` per provider SDK. Evidence: the `targets:` array. Names such as `Domain`, `Application`, `Infrastructure`, `Adapters`, `Mappings` are a finding.
- The executable is the one product. Evidence: `products:`.
- Organization packages are pinned by tagged URL. Evidence: any `.package(path:` is a finding.
- Dependencies come from the swift-microservices packages and `<project>-core`. Evidence: a package whose name ends in `-service-kit`, or a product named for an identity kit that no longer exists, is a finding; so is a `Database`, `PostgresDatabase`, `PostgresScope`, `MockDatabase`, or `PostgresClient.withClient` declared inside the service (`grep -rn "protocol Database\|struct PostgresDatabase\|protocol PostgresScope\|struct MockDatabase\|func withClient" Sources Tests`).
- Every target declares only the products it imports, and every declared package is used by some target. Evidence: compare each target's `import` lines with its `dependencies:`.
- `<Service>Core` links `Persistence`, `<Project>Authentication`, and `Logging`, and never a driver, grpc-swift, protobuf, a logging backend, configuration, a provider SDK, or a server framework. Evidence: the Core target's `dependencies:` and `grep -rn "^import" Sources/<Service>Core`.
- `swiftLanguageModes: [.v6]` is set. Then run `swift build`; a failure is blocking, quote the first error.

**2. Core** — read `Sources/<Service>Core`.
- Entities and commands are immutable `Sendable` structs; a create command carries no identifier and no persistence-stamped date. Evidence: `grep -rn "let id" Sources/<Service>Core/**/Commands`.
- A Core type is `Codable` only when something encodes it, usually the workflow state and result a workflow-client port returns. Evidence: `grep -rn "Codable\|Encodable\|Decodable" Sources/<Service>Core`; a conformance with no encoder, decoder, or Temporal port behind it is a finding.
- Each use case is generic over `DatabaseType` with `DatabaseType.Scope: XUseCaseScope`, exposes an `XUseCaseProtocol`, and uses typed throws. Evidence: the use case's declaration line.
- The identity is in the signature: `input:` alone, `subject: UserIdentity, input:`, or `service: ServiceIdentity, input:`. A use case that reads `ServiceContext` is a finding; so is a parameter named for a retired payload type.
- Authorization is a `guard` at the top of the body throwing the use case's own `.forbidden`; fixed invariants are guards before any I/O. A validator type with an error-mapping initializer, or an injected concrete collaborator with no protocol, is a finding.
- Every unit of work is `database.withTransaction`; no remote call inside it. Evidence: grep for client calls inside a `withTransaction` closure.
- Every use case takes a `Logger` as its last initializer parameter and logs the domain event; the catch-all that maps to `.unknown` logs `String(reflecting: error)`. Evidence: the `catch {` block.
- Concurrency is resolved rather than silenced: no `@unchecked Sendable` without a comment saying what makes it safe, no semaphore or ad-hoc lock inside an async context, concurrency structured rather than detached, so every task lives in a task group or in the `ServiceGroup` and cancellation reaches every worker loop and stream. Evidence: `grep -rn "@unchecked Sendable\|DispatchSemaphore\|Task.detached" Sources`. Judging an isolation question is the `swift-concurrency` skill's ([AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill)); load it rather than ruling from the diagnostic.
- No `Date()`, clock, or `now` closure is injected to stamp a record; a `Clock` injected where a use case decides on time (an expiry, a grace period) is the allowed alternative, not a finding.

**3. Persistence** — read `Sources/<Service>Postgres` and the migration list.
- The role migrations precede every table, and the serving process never connects as the owner: by default `CreateServiceRole` first, then `CreateInternalRole` on a tenant service and `CreateWorkerRole` with a worker; other names are a project choice, not a finding, provided a tenant-scoped role and an unscoped role are distinct with distinct secrets. No role has `BYPASSRLS` (`grep -rn BYPASSRLS Sources`).
- Every table's identifier is database-generated, `UUID PRIMARY KEY DEFAULT uuidv7()` by default or `gen_random_uuid()` on an older instance; a create command or request carrying an id is a finding. Dates are nouns (`creation_date`, not `created_at`; `creationDate`, not `createdAt`). Evidence: `grep -rn "_at\b\|At:" Sources`.
- Every table whose rows belong to users has a tenant-isolation policy on `app.caller_user_id`, in both `USING` and `WITH CHECK`, and the internal and worker roles get their own `TO "<role>" USING (true)` version. Evidence: `grep -rn "CREATE POLICY" -A 3 Sources/<Service>Postgres/Migrations`. A tenant table with no policy, a policy without `WITH CHECK`, or a predicate that admits rows beyond the caller's own, is blocking. A package with no user-owned tables (a single-tenant application, an internal tool) has no policies, one service role, and no settings interceptor or middleware; that is not a finding when the README or decision record says so, and an advisory to record it when nothing does.
- One scope type per database role, each conforming to `PostgresScope` and to the use-case scopes it admits. Evidence: `Sources/<Service>Postgres/Scopes`.
- Statements are `PostgresPreparedStatement` values in `Statements/<Entity>`; repositories translate `PSQLError` and SQLSTATE into `XRepositoryError`, naming the constraint that exists. A `PSQLError` reaching Core is a finding.
- A retryable create has a unique idempotency key enforced by the database with `ON CONFLICT`, and a state transition is guarded in `WHERE`. Evidence: the statement SQL.
- Migrations are named for their result, one create per table, unqualified table names, no service-named schema.

**4. Contracts and transport** — read `Sources/<Service>GRPC` and the proto dependency.
- Canonical protos have one home: `<project>-protos` by tag in microservices, with no `.proto` in a service; `Sources/<Module>GRPC/Protos/` with the generator plugin in a gRPC monolith. A `.proto` duplicated in a second package is a finding.
- The contract is split by audience: `<Entity>PublicService`, `<Entity>Service`, `<Entity>InternalService`, one conformance each at the feature root, holding only that audience's use cases.
- Conversions live in the feature's `Protobuf/` directory as `X+Protobuf.swift`, as initializers on the destination type or inline construction in the one method that needs it; transport validation (UUID parsing, enum recognition) happens in the conversion initializer; `.unspecified` and `.UNRECOGNIZED` are refused, not defaulted. A conversion written as a computed property or a `toX()` method is a finding. Evidence: `grep -rn "var proto\|var message\|var response\|func to[A-Z]" Sources`.
- Each handler on the user or internal service first requires its identity from `ServiceContext` with a private guard answering `.unauthenticated`, then maps use-case failures to stable codes: `.forbidden` to `permissionDenied`, not found to `notFound`, `.unknown` to `internalError`. A handler that decides authorization itself is blocking.
- UUIDs are lowercased on the wire. Generated messages appear only in this target and consumer adapters.

**5. Identity and access** — read `Serve.swift` and the manifest.
- `UserIdentity` is the one `JWTPayload` type, keys `sub` as a `UUID`, and verifies expiry in `verify(using:)`; additional claims are stored properties on it, and a second payload type or a converting initializer is a finding. Verification uses `JWTAuthenticator<UserIdentity>(publicKey:)`; only the authenticating service builds `JWTIssuer<UserIdentity>(privateKey:)`. A symmetric secret shared between processes, a private key outside the authenticating service, or a key read from an environment variable rather than a path, is blocking; a symmetric key inside a single-process monolith is not a finding.
- `BearerAuthenticationInterceptor` is applied to the user service, then `UserSettingsInterceptor` on a tenant service, `CertificateAuthenticationInterceptor(authenticator: ServiceAuthenticator())` to the internal service, nothing to the public service, each with `.apply(_, to: .services([descriptor]))`. Evidence: `interceptorPipeline:`. An interceptor on the public service, a per-method exclusion list, or a settings interceptor before the bearer interceptor, is a finding.
- Outgoing clients carry `BearerPropagationInterceptor<UserIdentity>` on user-service descriptors alone; a client that speaks as the process carries no interceptor and no token.
- No `@TaskLocal` carries a caller (`grep -rn "@TaskLocal" Sources`). The logging bootstrap passes `.user`, and `.service` where processes are admitted.
- No token, API key, shared secret, or `service` role is used to prove a process: a process is proved by its certificate and named by its `spiffe://` URI SAN.

**6. Composition** — read `Serve.swift` and `Configuration/`.
- `// MARK:` sections in the order Configuration, Logging, Infrastructure, Composition, gRPC, Lifecycle.
- `serve` is the default subcommand, and migrations run before serving: `serve --migrate-database` by default, or a `migrate` subcommand used as a one-shot job before the rollout; a migrate path the serving container also runs unguarded, or no migration path at all, is a finding. A Temporal worker is `worker run` on the same executable with its own composition root.
- Configuration is read through `ConfigReader` scoped by concern; infrastructure hosts and secrets are required; only listen address, port, log level, and the service's own identity default. An upstream host defaulting to `localhost` is a finding.
- Key material is configured by path and opened in a `Configuration/` extension. Two `static func mTLS(config:)` factories exist, one per direction; a plaintext mode or a mode variable is blocking.
- One `PostgresClient` per role; one `PostgresDatabase` per database built with `PostgresDatabase(client:logger:)`; a comment says which database each use case runs on.
- Logging is bootstrapped inline with the service name as label and the identity metadata providers, shipping structured logs to one aggregator: stdout plus in-process shipping by default, or stdout alone where the platform collects it; every long-lived client, server, and worker is in one `ServiceGroup` with graceful shutdown.

**7. Tests** — read `Tests/<Service>CoreTests`, and `Tests/<Service>WorkflowsTests` where the service has Workflows.
- The target depends on Core, `Logging`, `<Project>Authentication`, and `<Project>Testing`; it is swift-testing, with no `@testable` and no XCTest.
- Mocks are actors in `Mocks/`, the database is built through a scoped `withDatabase` helper over `MockDatabase`, subjects come from `makeSubject(role:)`, dates are fixed.
- Every use case has the success path of each overload, every guard including the authorization guard asserting the repository was never reached, and one test per case of its error enum. List each use case with a missing row of that matrix.
- No test binds a `ServiceContext` or drives an interceptor.
- With a `<Service>Workflows` target, `<Service>WorkflowsTests` runs every Workflow on the time-skipping test server in `.serialized` suites, covers each branch and one non-retryable failure, and replays recorded histories. A Workflow with no end-to-end test, a branch no test reaches, or a suite that round-trips payloads by hand instead is a finding. Evidence: `grep -rn "temporalTimeSkippingTestServer\|WorkflowReplayer" Tests`.
- Then run `swift test`; a failure is blocking, quote it.

**8. Delivery** — read `.github/workflows`, the Containerfile, and `Package.resolved`.
- The executable commits `Package.resolved`; CI resolves from it. The image is built for the deployment architecture with the static Linux SDK.
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

Order findings by severity, then by the audit section they came from. Omit an empty severity heading. Every finding carries a file and line, or the exact grep that came back empty. "Passed" lists the checks that held, one line each, so the user can see what was looked at and not only what was wrong. If `swift build` or `swift test` was not run, say why.
