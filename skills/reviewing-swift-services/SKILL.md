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

## Locate the package

The package is `$ARGUMENTS` when given, otherwise the current directory. Confirm it before auditing: a `Package.swift` whose targets follow `<Service>Core`, `<Service>Postgres`, `<Service>GRPC`, `<Service>`, or an API gateway with `API` and `<Project>`. If neither shape is present, report that the directory is not a service or gateway package and stop.

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
- Each use case is generic over `DatabaseType` with `DatabaseType.Scope: XUseCaseScope`, exposes an `XUseCaseProtocol`, and uses typed throws. Evidence: the use case's declaration line.
- The identity is in the signature: `input:` alone, `subject: UserIdentity, input:`, or `service: ServiceIdentity, input:`. A use case that reads `ServiceContext` is a finding; so is a parameter named for a retired payload type.
- Authorization is a `guard` at the top of the body throwing the use case's own `.forbidden`; fixed invariants are guards before any I/O. A validator type with an error-mapping initializer, or an injected concrete collaborator with no protocol, is a finding.
- Every unit of work is `database.withTransaction`; no remote call inside it. Evidence: grep for client calls inside a `withTransaction` closure.
- Every use case takes a `Logger` as its last initializer parameter and logs the domain event; the catch-all that maps to `.unknown` logs `String(reflecting: error)`. Evidence: the `catch {` block.
- No `Date()`, clock, or `now` closure is injected to stamp a record.

**3. Persistence** — read `Sources/<Service>Postgres` and the migration list.
- The first registered migration is `CreateServiceRole`; a tenant service registers `CreateInternalRole`, a service with a worker `CreateWorkerRole`; no role has `BYPASSRLS` (`grep -rn BYPASSRLS Sources`).
- Every table's identifier is `UUID PRIMARY KEY DEFAULT uuidv7()`; dates are nouns (`creation_date`, not `created_at`; `creationDate`, not `createdAt`). Evidence: `grep -rn "_at\b\|At:" Sources`.
- Every policy is the tenant predicate on `app.caller_user_id` and nothing else. Evidence: `grep -rn "CREATE POLICY" -A 3 Sources/<Service>Postgres/Migrations`. A predicate that reads any other `current_setting` (a role, a scope), that lists an administrator or a process role, or that the internal and worker roles do not get their own `TO "<role>" USING (true)` version of, is blocking.
- One scope type per database role, each conforming to `PostgresScope` and to the use-case scopes it admits. Evidence: `Sources/<Service>Postgres/Scopes`.
- Statements are `PostgresPreparedStatement` values in `Statements/<Entity>`; repositories translate `PSQLError` and SQLSTATE into `XRepositoryError`, naming the constraint that exists. A `PSQLError` reaching Core is a finding.
- A retryable create has a unique idempotency key enforced by the database with `ON CONFLICT`, and a state transition is guarded in `WHERE`. Evidence: the statement SQL.
- Migrations are named for their result, one create per table, unqualified table names, no service-named schema.

**4. Contracts and transport** — read `Sources/<Service>GRPC` and the proto dependency.
- Canonical protos come from `<project>-protos` by tag; no `.proto` in the service.
- The contract is split by audience: `<Entity>PublicService`, `<Entity>Service`, `<Entity>InternalService`, one conformance each at the feature root, holding only that audience's use cases.
- Conversions live in the feature's `Protobuf/` directory as `X+Protobuf.swift`; transport validation (UUID parsing, enum recognition) happens in the conversion initializer; `.unspecified` and `.UNRECOGNIZED` are refused, not defaulted.
- Each handler on the user or internal service first requires its identity from `ServiceContext` with a private guard answering `.unauthenticated`, then maps use-case failures to stable codes: `.forbidden` to `permissionDenied`, not found to `notFound`, `.unknown` to `internalError`. A handler that decides authorization itself is blocking.
- UUIDs are lowercased on the wire. Generated messages appear only in this target and consumer adapters.

**5. Identity and access** — read `Serve.swift` and the manifest.
- Verification uses `JWTAuthenticator<UserIdentity>(publicKey:)`; only the authenticating service builds `JWTIssuer<UserIdentity>(privateKey:)`. A shared HMAC secret, a private key outside the authenticating service, or a key read from an environment variable rather than a path, is blocking.
- `BearerAuthenticationInterceptor` is applied to the user service, then `UserSettingsInterceptor` on a tenant service, `CertificateAuthenticationInterceptor(authenticator: ServiceAuthenticator())` to the internal service, nothing to the public service, each with `.apply(_, to: .services([descriptor]))`. Evidence: `interceptorPipeline:`. An interceptor on the public service, a per-method exclusion list, or a settings interceptor before the bearer interceptor, is a finding.
- Outgoing clients carry `BearerPropagationInterceptor<UserIdentity>` on user-service descriptors alone; a client that speaks as the process carries no interceptor and no token.
- No `@TaskLocal` carries a caller (`grep -rn "@TaskLocal" Sources`). The logging bootstrap passes `.user`, and `.service` where processes are admitted.
- No token, API key, shared secret, or `service` role is used to prove a process: a process is proved by its certificate and named by its `spiffe://` URI SAN.

**6. Composition** — read `Serve.swift` and `Configuration/`.
- `// MARK:` sections in the order Configuration, Logging, Infrastructure, Composition, gRPC, Lifecycle.
- `serve` is the default subcommand with `--migrate-database`; there is no migrate subcommand; a Temporal worker is `worker run` on the same executable with its own composition root.
- Configuration is read through `ConfigReader` scoped by concern; infrastructure hosts and secrets are required; only listen address, port, log level, and the service's own identity default. An upstream host defaulting to `localhost` is a finding.
- Key material is configured by path and opened in a `Configuration/` extension. Two `static func mTLS(config:)` factories exist, one per direction; a plaintext mode or a mode variable is blocking.
- One `PostgresClient` per role; one `PostgresDatabase` per database built with `PostgresDatabase(client:logger:)`; a comment says which database each use case runs on.
- Logging is bootstrapped inline with stdout plus in-process shipping and the service name as label; every long-lived client, server, and worker is in one `ServiceGroup` with graceful shutdown.

**7. Tests** — read `Tests/<Service>CoreTests`.
- The target depends on Core, `Logging`, `<Project>Authentication`, and `<Project>Testing`; it is swift-testing, with no `@testable` and no XCTest.
- Mocks are actors in `Mocks/`, the database is built through a scoped `withDatabase` helper over `MockDatabase`, subjects come from `makeSubject(role:)`, dates are fixed.
- Every use case has the success path of each overload, every guard including the authorization guard asserting the repository was never reached, and one test per case of its error enum. List each use case with a missing row of that matrix.
- No test binds a `ServiceContext` or drives an interceptor. Then run `swift test`; a failure is blocking, quote it.

**8. Delivery** — read `.github/workflows`, the Containerfile, and `Package.resolved`.
- The executable commits `Package.resolved`; CI resolves from it. The image is built for the deployment architecture with the static Linux SDK.
- Every commit to a deployment branch publishes a SHA tag and the branch tag; the deploy step is mandatory, not skipped on a missing secret. A pre-existing infrastructure failure, such as a runner the account cannot bill, is reported as a decision, not a defect of the service.
- Migrations run at boot with `serve --migrate-database` from a short-lived owner client; the serving clients never hold owner credentials.

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
