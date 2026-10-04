---
name: writing-swift-server-code
description: Writes Swift for packages built the swift-microservices way, libraries and services alike. Swift tools 6.3 and Swift 6 language mode, the four shared upcoming features attached to every target, nonisolated default isolation, the settled concurrency rules, FoundationEssentials behind the conditional import, FormatStyle and ParseStrategy instead of legacy formatters, dependency traits that keep full Foundation out, Codable only where something encodes, conversions as initializers on the destination, file style, headers, and formatting. Use when writing Swift source or Package.swift settings in a Swift server package or library, choosing Foundation APIs, date or number formatting, or dependency traits, or resolving a strict-concurrency, import-visibility, or existential diagnostic in one.
paths: "Package.swift,Sources/**/*.swift,Tests/**/*.swift"
---

# Writing Swift server code

The language-level conventions every Swift package in the system shares, whatever it is: a reusable library on the [swift-microservices](https://github.com/swift-microservices) packages, `<project>-core`, a service, a monolith, or a gateway. What a package contains is another skill's subject — building-swift-services for services and monoliths, building-swift-http-surfaces for HTTP, building-swift-server-libraries for reusable libraries — and each of them follows this one for the Swift inside.

Read applicable `AGENTS.md` files first: their project profile, styles, and recorded exceptions override these general conventions. Preserve unrelated established code and formatting.

## Load the references

| Task | Read |
| --- | --- |
| Creating or editing a manifest, adding a target, or a concurrency, import, or existential diagnostic | [swift-settings.md](references/swift-settings.md) |
| Any Foundation import, date or number formatting or parsing, JSON coding, ByteBuffer helpers, or a dependency's traits or version | [foundation.md](references/foundation.md) |
| Creating or editing any Swift file | [style.md](references/style.md) |
| Tasks, actors, `Sendable`, isolation, or a data-race diagnostic | the `swift-concurrency` skill, [AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) — install it; this skill does not restate it |

## Principles

1. **Concurrency is checked by the compiler rather than by convention.** Every package builds in Swift 6 language mode with strict concurrency and no diagnostic silenced to get there. A server holds one process open for every caller at once, so a data race is a production incident rather than a flicker, and the language is the only thing that can rule one out ahead of time.
2. **Concurrency is structured.** A task that lives inside a scope is one the compiler can see the end of, one cancellation reaches, and one that cannot outlive the request that started it. A detached task has none of those properties and needs a stated reason.
3. **Use modern Foundation APIs and link only what is needed.** Our code stays on FoundationEssentials and the Swift-first formatting APIs even where an upstream library requires full Foundation; which APIs we call and what the graph links are separate questions with separate evidence.
4. **A conformance is earned, not defaulted.** `Codable`, `public`, `@unchecked Sendable`, and `@concurrent` each state a fact about a type; declare one only where that fact is true and used.

## Rules

1. Use Swift tools 6.3, `platforms: [.macOS(.v15)]`, `swiftLanguageModes: [.v6]`, and one stored `swiftSettings` array enabling exactly `ExistentialAny`, `MemberImportVisibility`, `InternalImportsByDefault`, and `NonisolatedNonsendingByDefault`, attached to every owned Swift library, executable, and test target. Settings do not propagate between targets or packages.
2. Keep nonisolated default isolation: no `.defaultIsolation(MainActor.self)` in a server package. Resolve diagnostics; never silence them with unsafe flags, `@preconcurrency`, or an uncommented `@unchecked Sendable`.
3. Plain imports are internal. Write `package import` or `public import` only where an imported type appears in that API, and import the module that supplies a member in every file that uses it, with its direct target dependency declared.
4. Use `@concurrent` only where an async function intentionally leaves the caller's actor, or to match a requirement of a dependency built without `NonisolatedNonsendingByDefault` (GRPCCore interceptors, Hummingbird `RouterMiddleware`, OpenAPI `ClientMiddleware`). A scoped callback API keeps a plain nonescaping, caller-isolated `(Scope) async throws -> T` with `T: Sendable` in its requirement, implementations, and test doubles alike.
5. An actor or `Mutex` for shared mutable state, never a semaphore or ad-hoc lock in an async context; a task group or `ServiceGroup` rather than a detached task; cancellation honoured in every worker loop and stream.
6. Import Foundation only through the `#if canImport(FoundationEssentials)` block, never an unconditional `import FoundationEssentials` (the macOS SDK has none) or a plain `import Foundation`. Format and parse with `FormatStyle` and `ParseStrategy`, never `DateFormatter`, `ISO8601DateFormatter`, `NumberFormatter`, or `String(format:)`. Take ByteBuffer helpers from `NIOFoundationEssentialsCompat`, never `NIOFoundationCompat`.
7. Declare `swift-configuration` with `traits: []`, `hummingbird` with only the traits it uses (`["ConfigurationSupport"]` with its configuration integration, otherwise `[]`), and `swift-openapi-runtime` with `traits: []`; a `from:` with no `traits:` argument leaves their full-Foundation defaults on. Check the newest compatible releases and their trait defaults before choosing versions, and record an unavoidable upstream full-Foundation requirement with its resolved version.
8. Conform a type to `Codable` only where something encodes or decodes it: a Temporal payload, a JSON body the process reads or writes, a token's claims, a cached value. Use `Encodable` alone for a value that is only written.
9. Convert one type into another with an initializer on the destination, in an extension beside the adapter that needs it; a throwing conversion is a visible `init(...) throws`.
10. `logger` is the last parameter of every initializer and function that takes one; only a trailing operation closure follows it. Log through the `swift-log` facade; only a composition root bootstraps the logging system.
11. Never declare a constant and assign it in a following block; produce the value where it is declared.
12. Keep the repository's header and formatter. Without one, copy the library formatter asset and use the compact SPDX header with the repository's license and owner.

## Completion gates

- Every owned Swift target receives the shared settings array, the package is in Swift 6 language mode with nonisolated default isolation, and `swift build` produces no concurrency diagnostic silenced rather than resolved.
- Every Foundation import is the conditional block; no code uses `DateFormatter`, `ISO8601DateFormatter`, `NumberFormatter`, or `String(format:)`; no target depends on `NIOFoundationCompat`; every declared `swift-configuration`, `hummingbird`, and `swift-openapi-runtime` has an explicit `traits:` argument naming only what it uses.
- Every `@unchecked Sendable` carries a comment stating what makes it safe; every `@concurrent` has a reason; no type is `Codable` without something encoding it.
- Claims that a graph avoids full Foundation rest on a linking check, not on a static SDK build or the imports alone; required upstream exceptions are recorded with their versions.
- Changed Swift passes the repository's formatter lint.
