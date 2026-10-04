---
type: llm
focus: { source: file, path: README.md }
---

PASS if the README's example `authenticate(_:)` returns a non-optional identity and its prose says an authenticator returns an identity or throws. Mentioning `nil` only to say it is no longer returned is fine.

FAIL if the README still tells readers that returning `nil` declines a credential, or its example still returns an optional.
