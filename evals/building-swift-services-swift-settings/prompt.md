---
max_turns: 50
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [building, swift-settings, concurrency]
---

Use the building-swift-services skill to create a small Swift 6.3 server utility package in the current directory with the organization's Swift settings. It exports a reusable library and a command-line application; add no infrastructure or dependencies.

- UtilityCore: `public struct Record: Sendable, Equatable` with `public let value: Int` and `public init(value:)`, and `public protocol OperationRunner: Sendable` whose `run(_:)` takes an async throwing operation returning a Sendable value and rethrows its error.
- UtilityAdapter (library product `UtilityAdapter`): `public struct InlineRunner: OperationRunner` with `public init()`, its `run(_:)`, and `public func record(value: Int) -> Record`. InlineRunner is a sequential scoped operation: the closure runs on the caller's actor and can mutate caller-owned non-Sendable state.
- UtilityExtensions: `extension String { public var utilityLabel: String }` returning `"utility: \(self)"`.
- UtilityApp (executable product `utility`): runs `{ 42 }` through an `OperationRunner` existential backed by InlineRunner and prints the result's `utilityLabel`, so it prints `utility: 42`.
- UtilityTests: Swift Testing coverage in Tests/UtilityTests/UtilityTests.swift for a custom actor and a MainActor caller.

Put InlineRunner in Sources/UtilityAdapter/InlineRunner.swift and the application in Sources/UtilityApp/main.swift. Briefly explain each setting, including tools version versus language mode and default actor isolation. Build and test where the environment permits; report limitations honestly. Do not commit or push.
