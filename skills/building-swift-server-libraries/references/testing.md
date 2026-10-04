# Testing a library

## Contents

- The test target
- What a library test proves
- Isolation contract tests
- Bindings and interceptors
- Real providers
- What not to test here

## The test target

One `<Module>Tests` target on swift-testing (`import Testing`, `@Suite`, `@Test`, `#expect`, `#require`), never XCTest, with the shared Swift settings and the library module as a `.target(name:)` dependency. A test imports the module plainly; needing `@testable` means the test is reaching for an implementation detail rather than the contract. Test doubles live in the test target, not in a product: a small `TableAuthenticator<Credential, Identity>` over a dictionary, a `ScopeDatabase<Scope>` that hands every unit of work a fixed scope. An organization-layer `<Project>Testing` product is the exception, because services share those doubles.

Name a suite for the type and a test for the behavior, with the display string stating the expectation: `@Test("A transaction preserves MainActor isolation across suspension")`.

## What a library test proves

Each public guarantee has a test a plausible regression would fail, and each test is a guarantee a consumer relies on:

- the shape consumers write against: a use case takes `any Database<Scope>` and is handed its scope, so a change to the protocol is a change to that test first;
- every documented branch: no credential continues unbound; a refused credential answers the transport's unauthenticated error with its stable message; an accepted one binds the principal in `ServiceContext` and in the framework's own state;
- error propagation: the error a consumer catches is the one its operation threw, not a wrapper;
- parsing tables: header and metadata parsing proven by a table of inputs and expected outputs (`Metadata.bearer`: first entry, case-insensitive scheme, empty token as absent, replacement on write).

Parameterize equivalent cases with explicit input/expected pairs; there is no quota of tests per type or overload.

## Isolation contract tests

A package that owns an API taking a caller-isolated callback — a `Database`, a runner, a client's `with…` method — tests that contract directly, because a regression to an actor hop still compiles for most callers. Call it from a custom actor and from a `@MainActor` test, each with a closure that mutates a non-`Sendable` reference the caller owns. Suspend inside the closure (`await Task.yield()` is enough) and check isolation on both sides of the suspension with `preconditionIsolated()` or `MainActor.preconditionIsolated()`: a closure that never suspends cannot detect a hop. Cover a thrown error propagating unchanged with the caller's captured state intact, and cancelling the caller's task mid-operation. Every implementation of the requirement, including drivers in other packages and shared test doubles, carries the same tests.

## Bindings and interceptors

Test a binding through the framework's own in-memory harness and nothing else: call a gRPC interceptor's `intercept` directly with a hand-built request and a closure for `next`; drive a Hummingbird middleware with HummingbirdTesting's router framework; drive a Vapor middleware with VaporTesting's in-memory application. Assert what the continuation observed (`ServiceContext.current`, the context's `identity`, `request.auth`), what the caller received, and that both carriers agree. Where a framework does not carry the task-local to the route (Vapor 4), do not write a test that assumes it does.

## Real providers

A driver proves its contract against the real provider: commit, rollback with the original error rethrown, settings visible inside the transaction and gone after it, merge order, and the scope's repositories on the transaction's connection. Read the connection from `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB`, and ship a `scripts/test.sh` that starts an ephemeral PostgreSQL 18 (a local installation or a `postgres:18` container) when none is configured and runs `swift test --parallel`. Mocks cannot prove transaction semantics, so a driver with no database configured proves nothing; CI always provides one, and a missing or unhealthy database fails the run (see [library-ci.md](../../delivering-swift-services/references/library-ci.md#capability-exceptions)). Tests that need no server — `withClient` isolation, cancellation, throwing — run without one.

## What not to test here

- A consumer's business rules, or an abstraction's semantics that only a driver can show: commit and rollback belong to the driver's package, not to swift-persistence.
- Generic framework behavior: that Hummingbird routes or that grpc-swift delivers metadata.
- Transport security and certificate renewal: they are composed by applications. An organization layer that documents mTLS composition may keep one contract suite for it in a separately named test target, so ordinary tests do not acquire its dependencies.
