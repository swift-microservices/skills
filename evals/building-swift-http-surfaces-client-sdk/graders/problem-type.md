---
type: llm
focus: { source: file, path: acme-sdk/Sources/AcmeSDK/Problem.swift }
---

PASS if `Problem` is a `public struct` conforming to `Codable` (or `Decodable` and `Encodable`), `Hashable`, `Sendable`, and `Error`, with public `type`, `title`, and `status` properties and optional `detail` and `instance`, matching the document's `Problem` schema, and a public initializer.

FAIL if the file is missing or empty, the type is not public, or it lacks `Error`, `Sendable`, `Hashable`, or Codable conformance.
Grade only against these criteria; do not fail for issues they do not mention.
