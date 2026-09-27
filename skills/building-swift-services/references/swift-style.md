# Swift and repository style

## Contents

- File form
- Foundation and modern APIs
- Layout
- Access and concurrency
- APIs and errors
- Conformances and conversions
- Formatting verification

Match existing files before applying these defaults. Preserve user-authored formatting in unrelated code.

## File form

Keep an Xcode-style header:

```swift
//
//  CreateItemUseCase.swift
//  <package-name>
//
//  Created by <author> on <date>.
//
```

Use the current date and the repository's author convention for new files when known. Do not rewrite historical headers.

Import no Foundation module when the standard library suffices. In files that need Foundation values, use `FoundationEssentials` directly when all supported platforms provide it, or this conditional import for SDK compatibility:

```swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
```

Order imports alphabetically by module name after any conditional Foundation block. Put one blank line between a conditional import block and other imports. Do not retain unused imports.

## Foundation and modern APIs

Follow Swift Foundation's direction toward Swift-first APIs and focused modules ([Swift Foundation announcement](https://forums.swift.org/t/swift-foundation-now-available/73530)). Use `FoundationEssentials` for values such as `Data`, `Date`, `UUID`, `URL`, `JSONEncoder`, and `JSONDecoder` when needed. The `Foundation` fallback above is for SDK availability; it does not permit legacy API usage. Avoid unnecessary module-qualified names such as `Foundation.JSONDecoder` that prevent using the Essentials module.

Never introduce legacy Foundation APIs in new or changed code: no `DateFormatter`, `ISO8601DateFormatter`, `NumberFormatter`, or `String(format:)`. Use modern `FormatStyle`, `ParseStrategy`, `formatted(_:)`, and standard-library operations where available for the supported toolchain and platforms. Verify API availability against current official documentation and the actual deployment targets; do not copy an older workaround or assume a modern API belongs to Essentials. If a requirement appears to need a legacy API, investigate the modern alternative and report the constraint rather than adding legacy code silently.

For machine-readable dates, use `Date.ISO8601FormatStyle` and its parse strategy, or `JSONDecoder.DateDecodingStrategy.iso8601` when it matches the wire contract. A custom JSON date strategy should parse with the modern style and convert invalid input into `DecodingError.dataCorruptedError`, rather than decoding with a cached formatter. For example, for ISO 8601 timestamps allowing optional fractional seconds on Swift 6.3 Linux:

```swift
let dateStyle = Date.ISO8601FormatStyle()
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .custom { decoder in
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    guard let date = try? dateStyle.parse(value) else {
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected an ISO 8601 timestamp"
        )
    }
    return date
}
```

Match the documented wire format instead of accepting unrelated date representations. Swift 6.2 changed [ISO 8601 parsing](https://github.com/swiftlang/swift-foundation/blob/main/Proposals/0021-ISO8601ComponentsStyle.md) to accept optional fractional seconds regardless of `includingFractionalSeconds`, and to accept hour-only offsets. That flag controls formatting, not strict input validation on newer runtimes. For tighter contracts, validate the required representation explicitly or investigate the newer `DateComponents.ISO8601FormatStyle` parsing APIs supported by the target runtime. Check behavior on supported Apple OS versions as well as Linux; newer parser behavior is not a promise about older Foundation runtimes. Test representative values, offsets, fractional-second rules, and rejected input when changing a serialized contract. For fixed numeric encodings such as hexadecimal, use `String(value, radix:)` and explicit padding rather than printf-style formatting.

Modern API usage and dependency size are separate questions. `Date.ISO8601FormatStyle` is implemented in [FoundationEssentials](https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/Formatting/Date%2BISO8601FormatStyle.swift); localized date and number styles generally need `FoundationInternationalization` and ICU. Import and link internationalization only for an actual localization requirement, and account for it in the linking policy. A full-Foundation dependency elsewhere in the graph never makes legacy APIs acceptable in our own code. Check releases and traits as described in [service-package.md](service-package.md).

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
- `logger` is always the last parameter — of an initializer, and of any function that takes one — and the last stored dependency, at every call site in the same position.

Use generic constraints in this form:

```swift
func withTransaction<T: Sendable>(
    _ operation: @Sendable (Scope) async throws -> T
) async throws -> T
```

Do not use `T : Sendable` or move the constraint to a trailing `where` unless the compiler requires it.

## Access and concurrency

- `package` for declarations shared across targets in one package.
- `private` for stored dependencies and implementation details.
- `public` only for packages consumed externally or an existing consumer's established API.
- Make protocols and values crossing concurrency boundaries `Sendable`.
- Use actors for mutable in-memory state such as an in-memory repository or a token session.
- Mark database operation closures `@Sendable`.
- Reach for `@unchecked Sendable` only with a comment saying what makes it safe. Silencing a diagnostic is not a reason, and on a server the race it hides is concurrent by default.
- Use structured concurrency: a task group, and `ServiceGroup` for anything long-lived. A detached task that nothing owns outlives the request that made it and ignores cancellation.
- Honour cancellation wherever work can run long, which on a server is every worker loop and every stream.
- Never a semaphore or an ad-hoc lock inside an async context. An actor or `Mutex` states the ownership the lock only implies.

The rest of Swift Concurrency is the `swift-concurrency` skill's subject ([AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill)), and following it is required rather than advisory. Load it before changing anything isolation-shaped instead of guessing from the diagnostic.
- Prefer immutable `let` properties.

## APIs and errors

- Use `callAsFunction` for use cases, with the principal first and the `input:` label: `useCase(input: input)`, `useCase(subject: subject, input: input)`, `useCase(service: service, input: input)`.
- Use typed throws for Core use-case protocols and implementations.
- Catch named enum cases directly: `catch ItemRepositoryError.duplicateName`.
- End with a deliberate catch-all mapping when the public typed error includes `.unknown`, and log the cause there with `String(reflecting:)`.
- Never declare a constant and assign it inside a following block — `let x: X` then `do { x = try … }`. Produce the value where it is declared: `guard let x = try? …` when every failure maps to one typed error, a private helper owning the do/catch when different failures map to different errors, or the value returned from the transaction closure.
- Log through the `swift-log` facade only: domain events in use cases (see [core.md](core.md)), request and infrastructure events at transport and composition boundaries. Never construct a log handler outside the composition root.

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

Construct the value inline instead when one method builds it once and nothing else ever will. Never convert with a computed property on the source, `var proto: <Organization>_Catalog_V1_Item`, or a `toProto()` method: the destination then has conversions scattered across every type that can become it, a throwing conversion hides behind property syntax, and the source learns every representation it is turned into. A configuration that picks a role or reads a secret on demand is not a conversion, and stays a property.

## Formatting verification

Use this `.swift-format` baseline when the repository does not already provide one:

```json
{
    "version": 1,
    "indentConditionalCompilationBlocks": false,
    "lineLength": 400,
    "indentation": {
        "spaces": 4
    }
}
```

`indentConditionalCompilationBlocks` must remain `false` so conditional `FoundationEssentials` and `Foundation` imports stay flush-left.

`lineLength` is deliberately `400`: the formatter must never mechanically wrap a line, so declarations break only where the author chooses. Do not lower it to a conventional 100/120 limit.

Use the repository's formatter if it has configuration or a formatting command. Otherwise, inspect changed Swift files and use `swift format lint --strict` only if the installed toolchain and existing project support it. Do not introduce a new formatting tool or reformat unrelated files.
