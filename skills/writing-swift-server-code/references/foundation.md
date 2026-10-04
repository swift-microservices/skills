# Foundation, modern APIs, and dependency traits

## Contents

- The conditional import
- Modern APIs
- Machine-readable dates
- Localization and linkage
- Dependency traits that pull in Foundation
- Upstream full-Foundation requirements
- Proving what links

Use FoundationEssentials when Foundation types are needed and the standard library is insufficient, use the modern Swift-first APIs, and link only what is needed. These are separate questions: which APIs our code uses, and what the resolved dependency graph links. A full-Foundation dependency elsewhere in the graph does not change which APIs our own code uses.

## The conditional import

Import no Foundation module when the standard library suffices. In files that need Foundation values, use this conditional import. The macOS SDK has no `FoundationEssentials` module, so any package that builds on Apple platforms — every package here declares `.macOS` — needs the fallback; an unconditional `import FoundationEssentials` compiles on Linux and fails on macOS:

```swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
```

Under `InternalImportsByDefault` the block is internal; write `public import` (or `package import`) on both branches when Foundation types appear in that API. Order plain imports alphabetically by module name at the top of the file, then the conditional block, separated by one blank line; swift-format's `OrderedImports` rule rejects plain imports that follow an `#if` block.

## Modern APIs

Follow Swift Foundation's direction toward Swift-first APIs and focused modules ([Swift Foundation announcement](https://forums.swift.org/t/swift-foundation-now-available/73530)). Use `FoundationEssentials` for values such as `Data`, `Date`, `UUID`, `URL`, `JSONEncoder`, and `JSONDecoder` when needed. The `Foundation` fallback above is for SDK availability only. Avoid unnecessary module-qualified names such as `Foundation.JSONDecoder` that prevent using the Essentials module.

Format and parse with `FormatStyle`, `ParseStrategy`, `formatted(_:)`, and standard-library operations, not `DateFormatter`, `ISO8601DateFormatter`, `NumberFormatter`, or `String(format:)`. Verify API availability against current documentation and the deployment targets; a modern API does not necessarily belong to Essentials. If a requirement seems to need one of those formatter classes, report the constraint. For fixed numeric encodings such as hexadecimal, use `String(value, radix:)` and explicit padding rather than printf-style formatting.

Take ByteBuffer/Data and Codable helpers from SwiftNIO's `NIOFoundationEssentialsCompat` product and import ([SwiftNIO 2.99.0](https://github.com/apple/swift-nio/releases/tag/2.99.0) and later), not `NIOFoundationCompat`, which links full Foundation.

## Machine-readable dates

Use `Date.ISO8601FormatStyle` and its parse strategy, or `JSONDecoder.DateDecodingStrategy.iso8601` when it matches the wire contract. A custom JSON date strategy should parse with the modern style and convert invalid input into `DecodingError.dataCorruptedError`, rather than decoding with a cached formatter. For example, for ISO 8601 timestamps allowing optional fractional seconds on Swift 6.3 Linux:

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

Match the documented wire format instead of accepting unrelated date representations. Swift 6.2 changed [ISO 8601 parsing](https://github.com/swiftlang/swift-foundation/blob/main/Proposals/0021-ISO8601ComponentsStyle.md) to accept optional fractional seconds regardless of `includingFractionalSeconds`, and to accept hour-only offsets. That flag controls formatting, not strict input validation on newer runtimes. For tighter contracts, validate the required representation explicitly or investigate the newer `DateComponents.ISO8601FormatStyle` parsing APIs supported by the target runtime. Check behavior on supported Apple OS versions as well as Linux; newer parser behavior is not a promise about older Foundation runtimes. Test representative values, offsets, fractional-second rules, and rejected input when changing a serialized contract.

## Localization and linkage

`Date.ISO8601FormatStyle` is implemented in [FoundationEssentials](https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/Formatting/Date%2BISO8601FormatStyle.swift); localized date and number styles generally need `FoundationInternationalization` and ICU. Import and link internationalization only for an actual localization requirement, and account for it in the linking policy.

## Dependency traits that pull in Foundation

Check the latest compatible releases and their trait defaults before choosing versions: upstream releases, tagged manifests, and toolchain and platform compatibility.

Some libraries have a `FullFoundation` trait, which may be enabled by default: [Hummingbird 2.27.0](https://github.com/hummingbird-project/hummingbird/blob/2.27.0/Package.swift) and [swift-openapi-runtime 1.12.1](https://github.com/apple/swift-openapi-runtime/blob/1.12.1/Package.swift) are examples. Inspect the manifest of the version being resolved; neither the trait's presence, its name, nor its default is universal. For these versions, disable default traits with `traits: []` when no optional feature is needed:

```swift
.package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.27.0", traits: []),
.package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.1", traits: []),
```

When other traits are required, list only those traits explicitly. Hummingbird's `traits: ["ConfigurationSupport"]` enables its swift-configuration integration and also leaves `FullFoundation` disabled. Never enable the full default set just to recover one feature.

Always opt out of default traits when declaring `apple/swift-configuration`: use `.package(url: "https://github.com/apple/swift-configuration.git", from: "1.2.0", traits: [])` for environment-based configuration. Its [1.2.0 manifest](https://github.com/apple/swift-configuration/blob/1.2.0/Package.swift) enables `JSON` by default; the [JSON provider](https://github.com/apple/swift-configuration/blob/1.2.0/Sources/Configuration/Providers/Files/JSONSnapshot.swift) uses `JSONSerialization` and imports full Foundation. The trait is named `JSON`, not `FullFoundation`. Environment-variable configuration does not need it, and decoding an HTTP JSON body is unrelated to parsing JSON configuration files. If a configuration provider genuinely requires an optional trait, select only that trait explicitly and document its linking cost; do not silently drop required provider functionality or restore all defaults.

A `from:` with no `traits:` argument on any of these three leaves its defaults, and so full Foundation, enabled.

[SwiftPM combines traits across the resolved graph](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/addingdependencies/): another dependency can enable `FullFoundation` or `JSON` again. Inspect transitive manifests and `swift package show-dependencies`; a direct `traits: []` declaration alone is not proof.

[LoggingLoki 2.0.1](https://github.com/lovetodream/swift-log-loki/blob/v2.0.1/Package.swift) declares `NIOFoundationEssentialsCompat` itself, so an executable linking LoggingLoki needs no NIO product for it. Add an explicit NIO dependency and product only when our target imports it directly.

## Upstream full-Foundation requirements

Some required server libraries link full Foundation: [Vapor 4.122.2](https://github.com/vapor/vapor/blob/4.122.2/Package.swift) and [PostgresNIO 1.33.1](https://github.com/vapor/postgres-nio/blob/1.33.1/Package.swift) pull in full Foundation and its internationalization/ICU libraries, and so do their consumers, including our Vapor and Postgres adapters. Check the resolved releases rather than assuming either way. A required library stays even when it links full Foundation; record the package and version as a documented constraint, and keep our own code on Essentials APIs. Do not promise an Essentials-only application from a framework's name alone.

## Proving what links

Static SDK success and conditional imports alone do not prove the resolved graph avoids full Foundation. The delivering skill describes [library consumer linking](../../delivering-swift-services/references/library-ci.md#capability-exceptions) and [service executable inspection](../../delivering-swift-services/references/services-ci.md#release-image-and-foundation) separately. Revisit a documented upstream requirement when the resolved dependency changes.
