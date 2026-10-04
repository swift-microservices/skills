# Swift settings

## Contents

- Tools version and language mode
- The shared settings array
- What each setting means
- Default isolation and diagnostics
- Concurrency rules that are settled here

These settings apply to every package the organization owns: a reusable library, a service, a monolith, a gateway, `<project>-core`, `<project>-protos`, and every Swift target inside them.

## Tools version and language mode

Use Swift tools 6.3 and `swiftLanguageModes: [.v6]`. Tools version selects manifest APIs and the minimum toolchain; language mode selects language semantics and enables Swift 6 strict concurrency checking. An upcoming feature opts a target into an implemented future language behavior; it is not an experimental feature and is not implied merely by tools version 6.3 or language mode 6.

Declare `platforms: [.macOS(.v15)]` in every package, so Apple-platform builds get the concurrency runtime, `Mutex`, and swift-testing the code relies on; Linux ignores it. Keep the tools version, language mode, platform floor, and these settings aligned across the organization's repositories unless the user asks to upgrade.

## The shared settings array

Define one stored `let` immediately after `import PackageDescription` (after the license header where the repository uses one), then pass `swiftSettings: swiftSettings` to every owned Swift `.target`, `.executableTarget`, and `.testTarget`. This includes application composition roots, workers, gateways, shared libraries, test-support libraries, and targets compiling generated Swift. Settings do not propagate from a library to its consumers, between targets, or into dependency packages. Keep C, binary, and plugin targets out of this list.

```swift
// swift-tools-version: 6.3
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    // SE-0335: spell protocol existential types with `any`.
    .enableUpcomingFeature("ExistentialAny"),
    // SE-0444: member lookup respects the imports visible in this file.
    .enableUpcomingFeature("MemberImportVisibility"),
    // SE-0409: an unqualified import has internal access.
    .enableUpcomingFeature("InternalImportsByDefault"),
    // SE-0461: nonisolated async functions inherit the caller's actor.
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "Example",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ExampleCore", targets: ["ExampleCore"]),
        .executable(name: "example", targets: ["Example"]),
    ],
    targets: [
        .target(name: "ExampleCore", swiftSettings: swiftSettings),
        .executableTarget(name: "Example", dependencies: ["ExampleCore"], swiftSettings: swiftSettings),
        .testTarget(name: "ExampleCoreTests", dependencies: ["ExampleCore"], swiftSettings: swiftSettings),
    ],
    swiftLanguageModes: [.v6]
)
```

A declared array that is never attached is insufficient, and so is attaching it to some targets: check every target.

## What each setting means

| Setting | Meaning |
| --- | --- |
| [`ExistentialAny` (SE-0335)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0335-existential-any.md) | Use `any Repository` for an existential value. Generic constraints and conformances stay `T: Repository` and `struct Store: Repository`. |
| [`MemberImportVisibility` (SE-0444)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md) | Members, including extensions, must come from a module visible in the current file. Import the module that supplies a member and declare its direct target dependency; another file's ordinary import is insufficient. |
| [`InternalImportsByDefault` (SE-0409)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md) | Plain `import` is internal. Use `package import` when imported types appear in package API, and `public import` when they appear in public API; keep implementation-only imports internal. `public import` does not re-export the module's names. Check conformances and inlinable code too. |
| [`NonisolatedNonsendingByDefault` (SE-0461)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md) | Nonisolated async functions and async function types without explicit isolation, `@Sendable` or not, use caller isolation by default (`nonisolated(nonsending)`). This avoids an implicit actor hop; it neither makes shared state safe nor prevents reentrancy at `await`. Use `@concurrent` only when an async function intentionally leaves the caller's actor, with safe values crossing that boundary, or to match a requirement of a dependency built without this feature (for example GRPCCore interceptors, Hummingbird `RouterMiddleware`, OpenAPI `ClientMiddleware`). |

## Default isolation and diagnostics

Default actor isolation is a separate setting: server packages and applications keep nonisolated default isolation and set no `.defaultIsolation(MainActor.self)`. A server holds one process open for every caller at once; blanket MainActor isolation would serialize it.

Diagnostics are resolved, never silenced with unsafe flags, `@preconcurrency`, or `@unchecked Sendable`. CI may add stricter compiler flags (warnings as errors, explicit target-dependency import checks, required explicit `Sendable`); those belong to the delivering skill's CI profiles, not to the manifest.

## Concurrency rules that are settled here

The rest of Swift Concurrency is the `swift-concurrency` skill's subject ([AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill)), and following it is required rather than advisory. Load it before changing anything isolation-shaped instead of guessing from the diagnostic. Settled regardless:

- An actor, or `Mutex`, for shared mutable state; never a semaphore or an ad-hoc lock inside an async context. An actor or `Mutex` states the ownership the lock only implies.
- `@unchecked Sendable` only with a comment stating what guarantees the safety, never to quiet a diagnostic; on a server the race it hides is concurrent by default.
- Structured concurrency: a task group, and one `ServiceGroup` owning every long-lived task. A detached task that nothing owns outlives the request that made it and ignores cancellation; it needs a stated reason.
- Cancellation honoured wherever work can run long, which on a server is every worker loop and every stream.
- An API that takes a scoped callback — a transaction, a runner, a client's `with…` method — keeps it a plain nonescaping `(Scope) async throws -> T` with `T: Sendable`, caller-isolated, with neither `@Sendable` nor `@concurrent`, in the protocol requirement, every implementation, and every test double alike. When forwarding to a dependency with an isolated parameter, pass `isolation: #isolation` as its API requires.
