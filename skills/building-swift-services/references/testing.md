# Testing

How a module's behavior is verified: the test targets, the mocks, what a use-case test covers, and what the transport tests cover. A service is a module in its own package, and its tests are the same. A package that defines a caller-isolated callback API also carries isolation contract tests; those are the building-swift-server-libraries skill's ([testing reference](../../building-swift-server-libraries/references/testing.md#isolation-contract-tests)).

## Contents

- [The test targets](#the-test-targets)
- [Values and the subject](#values-and-the-subject)
- [Mocks](#mocks)
- [The scoped database helper](#the-scoped-database-helper)
- [What a use-case test covers](#what-a-use-case-test-covers)
- [What a use-case test does not cover](#what-a-use-case-test-does-not-cover)
- [Transport tests](#transport-tests)

## The test targets

Every module carries `<Module>CoreTests` (`<Service>CoreTests` in a service; one per module in a monolith), depending on the Core target, the `swift-log` facade, `<Project>Authentication`, and `<Project>Testing`. A module that serves RPCs also carries `<Module>GRPCTests`. Both manifests are in [service-package.md](service-package.md#manifest-of-a-modules-targets). `<Project>Testing` is the one product a test target links that a production target never may.

Tests are swift-testing — `@Suite`, `@Test`, `#expect`, `#require` — never XCTest. Targets of one package use `package` access, so a test target imports Core plainly; `@testable` is never needed, and needing it signals a wrong access level. In a monolith a module's tests import that module's Core alone. Suites are named for the feature (`@Suite("User use cases")`), test functions for the behavior, and the display string states the expectation as a sentence: `@Test("duplicate repository errors become create use-case errors")`.

A module with Temporal adds `<Module>WorkflowsTests` ([testing.md](../../orchestrating-temporal-workflows/references/testing.md) in the orchestrating-temporal-workflows skill). Use-case tests stay here, over mocks.

```text
Tests/<Module>CoreTests/
  Mocks/
    <Entity>UseCaseMocks.swift      # actor repositories, the mock scope, makeSubject
    WithDatabase.swift
  Support/
    Values.swift
  <Entity>UseCaseTests.swift
```

## Values and the subject

Fixed values live in `Support/Values.swift`, so an assertion against a mock's output is reproducible:

```swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension UUID {
    static let user = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let missing = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
}

extension Date {
    static let reference = Date(timeIntervalSince1970: 1_700_000_000)
}
```

The subject factory builds the principal a user use case takes, over the fixed date; a "reads their own row" test passes the stored row's id, an authorization test the role:

```swift
func makeSubject(id: UUID = .user, role: UserRole = .user) -> UserIdentity {
    UserIdentity(
        userId: id,
        role: role,
        issuer: "users-core-tests",
        issueDate: .reference,
        expirationDate: Date.reference.addingTimeInterval(60)
    )
}
```

Where Core declares its own enum named like `<Project>Authentication`'s `UserRole`, qualify the parameter type with the module name. An internal use case takes business input directly; test its invariants without manufacturing a caller.

A use case that decides on time reads `Date.now`, so a test of that decision builds its dates relative to `Date.now` with a clear margin — a minute past or a minute ahead — never at the boundary. Everything else uses `.reference`, never `Date()`.

## Mocks

Mocks live in `Mocks/`, mirror the shapes Core declares, and are the module's own; only `MockDatabase` and `MockUserAuthenticator`, which every module would write identically, come from `<Project>Testing`.

**A mock repository is an actor** holding a dictionary keyed by id, an optional injected failure, and a `calls` counter every method increments. Guard tests assert `calls == 0` after a refusal: unchanged data alone cannot prove no read occurred.

```swift
actor MockUserRepository: UserRepository {
    private(set) var calls = 0
    private var users: [UUID: User]
    private let createFailure: UserRepositoryError?

    init(users: [User] = [], createFailure: UserRepositoryError? = nil) {
        self.users = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        self.createFailure = createFailure
    }

    func create(_ command: CreateUserCommand) async throws -> User {
        calls += 1
        if let createFailure {
            throw createFailure
        }
        let user = User(id: .user, name: command.name, email: command.email, status: .active, creationDate: .reference, updateDate: .reference)
        users[user.id] = user
        return user
    }

    func find(id: UUID) async throws -> User? {
        calls += 1
        return users[id]
    }
}
```

**`MockDatabase` comes from `<Project>Testing`**: a `Database` with no transaction and a fixed scope, so the test asserts against the repositories it built the scope from. **A mock scope** is a struct conforming to every use-case scope the suite exercises:

```swift
struct MockUserScope: CreateUserUseCaseScope, GetProfileUseCaseScope, GetUserByIDUseCaseScope, ListUsersUseCaseScope {
    let userRepository: any UserRepository
}
```

When a scope needs several repositories, group the mocks in one struct so a test builds and inspects them together:

```swift
struct EntitlementMockRepositories {
    let entitlements: MockEntitlementRepository
    let devices: MockDeviceRepository
}
```

## The scoped database helper

Construct the mock database through one scoped helper in `Mocks/WithDatabase.swift`, and write test bodies inside it. `T` carries no `Sendable` constraint: the operation runs in the caller's isolation.

```swift
import UsersCore
import <Project>Testing

func withDatabase<T>(
    repository: any UserRepository,
    operation: (MockDatabase<MockUserScope>) async throws -> T
) async rethrows -> T {
    let database = MockDatabase(scope: MockUserScope(userRepository: repository))
    return try await operation(database)
}
```

With several repositories the helper takes the `…MockRepositories` struct instead. The scoped shape keeps every call site unchanged if a variant later provisions a real ephemeral database, and `rethrows` lets a test whose closure cannot throw call it without `try`.

```swift
@Test("listing as a user is refused before any read")
func listAsUserIsForbidden() async {
    let repository = MockUserRepository(users: [makeUser()])
    await withDatabase(repository: repository) { database in
        let useCase = ListUsersUseCase(database: database, logger: Logger(label: "users-core-tests"))
        await #expect(throws: ListUsersUseCaseError.forbidden) {
            _ = try await useCase(subject: makeSubject(role: .user))
        }
    }
    #expect(await repository.calls == 0)
}
```

## What a use-case test covers

Test the decisions the use case owns, through its public surface, against mocks alone:

1. **The success path**: the use case reads or mutates the repository as specified, and the result carries the expected values.
2. **Every guard**: input the use case refuses before I/O throws its own typed error and leaves `calls == 0`. The authorization guard is one of these — `makeSubject(role: .user)` against an administrator's use case throws `.forbidden` and touches nothing.
3. **Meaningful error classifications**: injected repository failures retain the distinctions callers act on. Parameterize equivalent paths with explicit input/expected pairs.

Keep a test when a plausible regression in code this package owns would fail it. There is no quota per error case, method, or overload; consolidate cases that exercise the same behavior. A mock's idempotent behavior does not establish database retry safety.

## What a use-case test does not cover

- **Identification.** Requiring a caller is the handler's per-RPC decision ([identity-and-access.md](identity-and-access.md#identifying-a-caller-versus-requiring-one)); use-case tests bind no `OperationContext` and need no token or interceptor. The principal arrives as a value.
- **Row confinement.** Row-level security is enforced by the database from the stamped transaction; a mock database cannot exercise it. Policies are verified against a real database as the roles ([migrations-and-rls.md](migrations-and-rls.md#row-level-security)).
- **Transport.** Status mapping is the transport tests' (below).

`swift test` then runs the Core targets in milliseconds with no containers, which lets CI run them on every pull request.

## Transport tests

Transport tests are both kinds, split by purpose:

- **Handler and router tests** over mocked collaborators — the module's use-case protocols, or one mocked generated client protocol per `<Entity>Service` in a gateway — never a database. They cover the tier and identity matrix (absent token `unauthenticated`/401, non-administrator `permissionDenied`/403, the use case not reached), request conversion, and the mapping of every use-case error to its status. On HTTP these drive HummingbirdTesting's `.router` (or `VaporTesting`) over an application composed as the root composes it, with a real `JWTIssuer` and `JWTAuthenticator` over a throwaway Ed25519 key ([surface.md](../../building-swift-http-surfaces/references/surface.md#tests)). On gRPC a handler test binds the principal with `OperationContext.withContext`, or runs the interceptor with `MockUserAuthenticator(["admin-token": admin])` and sends `Bearer admin-token`.
- **One live loopback TLS suite per gRPC module**, `<Module>GRPCTests`, for what only the wire proves: the servers and their interceptor pipelines as the root builds them, token verification at the receiver (an invalid, an expired, and a wrongly signed token), bearer propagation on `<Entity>Service` descriptors only, internal-service admission by certificate, and each listener's transport configuration. Each listener is dialed as its real callers dial it: a client-facing listener with server TLS and a bearer token and no client certificate (an internal descriptor answers `unimplemented` there), an internal listener with mTLS (a client without a certificate is refused). A microservice's one listener is internal, so its suite is mTLS throughout. It mints a throwaway CA and leaf pairs with swift-certificates and swift-crypto, serves on `127.0.0.1` port `0`, and dials with full server verification against `localhost`:

```swift
// Tests/UsersGRPCTests/TLSFixtures.swift (excerpt)
struct TestCA: Sendable {
    let key: Certificate.PrivateKey
    let certificate: Certificate

    init() throws {
        key = Certificate.PrivateKey(P256.Signing.PrivateKey())
        let name = try DistinguishedName { CommonName(UUID().uuidString) }
        certificate = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: key.publicKey,
            notValidBefore: Date.now.addingTimeInterval(-60),
            notValidAfter: Date.now.addingTimeInterval(86_400),
            issuer: name,
            subject: name,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: try Certificate.Extensions {
                Critical(BasicConstraints.isCertificateAuthority(maxPathLength: nil))
                Critical(KeyUsage(keyCertSign: true))
            },
            issuerPrivateKey: key
        )
    }
}
```

The client-facing client is `.tls { $0.trustRoots = …; $0.serverCertificateVerification = .fullVerification }` with no certificate chain. A leaf is issued by the CA with `ExtendedKeyUsage([.serverAuth, .clientAuth])` and `SubjectAlternativeNames([.dnsName("localhost")])`, written as PEM files to a temporary directory the test removes, and loaded through `TimedCertificateReloader.makeReloaderValidatingSources`. The fixture server runs the module's services over `MockDatabase` and a fixture repository inside a `ServiceGroup` in a task group, reads the bound port from `transport.listeningAddress`, and triggers graceful shutdown when the body returns; give the suite a `.timeLimit` and every call a short `CallOptions.timeout`.

A transport test asserts routing, identification, conversion, and status; what the use case decides is the use-case test's. Test generic TLS rejection and reload mechanics once in the owning shared library's suite; repeat a case here only when it exercises this module's configuration. Keep setup isolated per case, `#require` before indexing fixture output, and observe async completion with bounded waiting rather than sleeping. Remove stale scenarios and unused fixture machinery after architecture changes.
