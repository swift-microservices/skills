# Swift style

## Contents

- File form
- Layout
- Access and concurrency
- APIs and errors
- Conformances and conversions
- Formatting verification

Match existing files before applying these defaults. Preserve user-authored formatting in unrelated code.

## File form

Keep the repository's header convention. A repository without one uses the compact SPDX header of the [library CI profile](../../delivering-swift-services/references/library-ci.md#formatting-and-headers), with the repository's own license and owner:

```swift
// Copyright (c) 2026 <owner>
// SPDX-License-Identifier: MIT
// See LICENSE for license information.
```

A repository whose profile records Xcode-style headers keeps them:

```swift
//
//  CreateItemUseCase.swift
//  <package-name>
//
//  Created by <author> on <date>.
//
```

Use the current date and the repository's author convention for new files when known. Rewrite historical headers only when an explicit profile change is requested.

Import no Foundation module when the standard library suffices; where Foundation values are needed, use the conditional `FoundationEssentials` block in [foundation.md](foundation.md). Order plain imports alphabetically by module name at the top of the file, then any conditional block, separated by one blank line. Do not retain unused imports.

## Layout

- Indent with four spaces; never tabs in Swift.
- One declaration per file, except tiny, tightly related conversion extensions.
- Trailing commas in multiline arrays and manifest dependency lists where the surrounding file does.
- Break multiline initializers one argument per line; break a signature with more than three parameters one parameter per line, with the closing parenthesis and return type on their own line.
- Build a command or statement into a named local, then execute it on the next line: `let statement = GetItemStatement(id: id)` then `connection.execute(statement, logger: logger)`. Collect a multi-row result with `try await Array(result)`.
- Write SQL longer than one clause as a multi-line string literal, one clause per line.
- Opening brace on the declaration line.
- Keep a type declaration and its qualified protocol conformances on one line; do not split the protocol name or put the opening brace on a separate line.
- A single blank line between logical blocks and declarations.
- No trailing whitespace and no whitespace-only lines.
- Keep lines readable, but do not mechanically wrap a generic `where` clause if the established code keeps the signature on one line.
- Prefer explicit, descriptive local names: `database`, `postgresClient`, `itemService`, `serverConfig`.
- `logger` is always the last parameter — of an initializer, and of any function that takes one — and the last stored dependency, at every call site in the same position. The one parameter that follows it is a trailing operation closure, as in `PostgresClient.withClient(configuration:logger:operation:)`.

Use generic constraints in this form:

```swift
func withTransaction<T: Sendable>(
    _ operation: (Scope) async throws -> T
) async throws -> T
```

Do not use `T : Sendable` or move the constraint to a trailing `where` unless the compiler requires it.

## Access and concurrency

- `package` for declarations shared across targets in one package.
- `private` for stored dependencies and implementation details.
- `public` only for packages consumed externally or an existing consumer's established API.
- Apply the shared [Swift settings](swift-settings.md) to library, executable, and test targets. Plain imports are internal: promote to `package import` or `public import` only when imported types appear in that API. Import member-providing modules in each file that uses them.
- Make protocols and values crossing concurrency boundaries `Sendable`.
- Use actors for mutable in-memory state such as an in-memory repository or a token session.
- Scoped callbacks, such as a transaction's, are plain, nonescaping `(Scope) async throws -> T` with `T: Sendable`, caller-isolated in protocol requirements, implementations, and test doubles alike (see *Concurrency rules that are settled here* in [swift-settings.md](swift-settings.md)).
- Prefer immutable `let` properties.
- `@unchecked Sendable`, locks, detached tasks, and cancellation follow the settled rules in [swift-settings.md](swift-settings.md); the rest of Swift Concurrency is the `swift-concurrency` skill's ([AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill)).

## APIs and errors

- In a service, use `callAsFunction` for use cases, one per use case, with the principal first when there is one and the `input:` label: `useCase(subject: subject, input: input)` for the caller's own and administrators' operations, and `useCase(input: input)` for public and internal ones; omit `input:` when the operation has no business input.
- Use typed throws for Core use-case protocols and implementations, and wherever a library's error set is closed and part of its contract.
- Catch named enum cases directly: `catch ItemRepositoryError.duplicateName`.
- End with a deliberate catch-all mapping when the public typed error includes `.unknown`, and log the cause there with `String(reflecting:)`.
- Never declare a constant and assign it inside a following block — `let x: X` then `do { x = try … }`. Produce the value where it is declared: `guard let x = try? …` when every failure maps to one typed error, a private helper owning the do/catch when different failures map to different errors, or the value returned from the transaction closure.
- Log through the `swift-log` facade only: domain events in use cases (the building skill's [Core reference](../../building-swift-services/references/core.md#logging-in-use-cases)), request and infrastructure events at transport and composition boundaries. A library accepts a `Logger`; it never bootstraps the logging system. Never construct a log handler outside a composition root.

## Conformances and conversions

`Codable` is a conformance a type earns by being encoded, not a default. Give it to a type only when something converts that type to or from a serialized form:

- a Temporal payload, and every type it holds;
- a JSON body the process writes or reads, such as a problem document or a provider's webhook;
- a token's claims;
- a value written to a cache.

An entity, command, value object, or enum in Core has none of those by default. Protobuf conversions build messages field by field, and Postgres rows go through `PostgresEncodable` and `PostgresDecodable`, so neither needs `Codable`. Each synthesised conformance is an `encode(to:)` and an `init(from:)` the compiler generates and type-checks on every build, for every type that declares it. A conformance nothing uses also invites passing the type somewhere it becomes a stored contract, which is how a domain model ends up in a workflow's history. Use `Encodable` alone for a value that is only written.

Removing a conformance needs one check the compiler cannot make: whether the type crosses Temporal, whose converter checks `Codable` at runtime. The orchestrating-temporal-workflows skill's Workflow tests are that check: they run every payload through the real converter.

Convert between types with an initializer on the destination type, in an extension beside the adapter that uses it:

```swift
extension <Organization>_Catalog_V1_Item {
    init(item: Item) {
        self.init()
        self.id = item.id.uuidString.lowercased()
        self.name = item.name
    }
}
```

Construct the value inline instead when one method builds it once and nothing else ever will. Conversions on the destination keep every way it can be made in one place, keep a throwing conversion a visible `init(...) throws`, and leave the source unaware of every representation it is turned into. A configuration that picks a role or reads a secret on demand is not a conversion, and stays a property.

## Formatting verification

Use the repository's formatter configuration and formatting command when it has them, and do not reformat unrelated files.

A repository without one copies the [library formatter asset](../../delivering-swift-services/references/library-ci.md#formatting-and-headers) byte-for-byte to `.swift-format`: four-space indentation, 150-column lines, ordered imports, and `indentConditionalCompilationBlocks: false` so conditional `FoundationEssentials` and `Foundation` imports stay flush-left. Reusable libraries and services on the standard [service CI profile](../../delivering-swift-services/references/services-ci.md#source-quality-and-headers) both use it.

A repository profile in `AGENTS.md` may record another style, such as four spaces with a 400-column limit and Xcode author headers; keep that style for every file in the repository, including new ones, and never mass-reformat it to the asset.

Lint changed Swift with `swift format lint --strict` where the toolchain supports it. Do not introduce a different formatting tool.
