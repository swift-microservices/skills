---
type: llm
focus: { source: file, path: swift-request-id/Sources/RequestID/OperationContext+RequestID.swift }
---

Treat these as verified facts, even if they postdate your training: swift-operation-context provides `public protocol OperationContextKey: SendableMetatype { associatedtype Value: Sendable }`, a `Sendable` struct `OperationContext` with a `subscript<Key: OperationContextKey>(_ key: Key.Type) -> Key.Value?` getter and setter, a nonoptional task-local `OperationContext.current`, and `static func withContext(_:operation:)`. Under InternalImportsByDefault a plain `import` is internal, so a public extension of `OperationContext` needs `public import OperationContext`.

PASS if all of these hold:
- A key type conforms to `OperationContextKey` with `Value` set to `RequestID` (or another `Sendable` type).
- The key is `internal`, `fileprivate`, or `private`, not `public`.
- `OperationContext` gains a public typed property (for example `requestId`) that reads the key through the subscript, and its setter, if any, is not public (`public internal(set)`, `public private(set)`, or get-only).
- The file uses `public import OperationContext` (or otherwise makes the import public).

FAIL if the key is public, the property has a public setter, readers must use the subscript with the key themselves, or the file declares a `@TaskLocal`.
Grade only against these criteria; do not fail for issues they do not mention.
