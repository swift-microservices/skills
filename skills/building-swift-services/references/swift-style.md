# Swift and repository style

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

Use conditional Foundation imports in production files that need Foundation values:

```swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
```

Order imports alphabetically by module name after any conditional Foundation block. Put one blank line between a conditional import block and other imports. Do not retain unused imports.

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
- Prefer immutable `let` properties.

## APIs and errors

- Use `callAsFunction` for use cases, with the principal first and the `input:` label: `useCase(input: input)`, `useCase(subject: subject, input: input)`, `useCase(service: service, input: input)`.
- Use typed throws for Core use-case protocols and implementations.
- Catch named enum cases directly: `catch ItemRepositoryError.duplicateName`.
- End with a deliberate catch-all mapping when the public typed error includes `.unknown`, and log the cause there with `String(reflecting:)`.
- Never declare a constant and assign it inside a following block — `let x: X` then `do { x = try … }`. Produce the value where it is declared: `guard let x = try? …` when every failure maps to one typed error, a private helper owning the do/catch when different failures map to different errors, or the value returned from the transaction closure.
- Log through the `swift-log` facade only: domain events in use cases (see [core.md](core.md)), request and infrastructure events at transport and composition boundaries. Never construct a log handler outside the composition root.

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
