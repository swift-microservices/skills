---
type: llm
focus: { source: file, path: AGENTS.md }
---

PASS if AGENTS.md now states that `authenticate` returns an identity or throws, and no longer says it returns `nil` to decline. Mentioning `nil` only to say it is no longer returned is fine.

FAIL if AGENTS.md still says `authenticate` returns `nil` to decline a credential, or still describes an optional result.
Grade only against these criteria; do not fail for issues they do not mention.
