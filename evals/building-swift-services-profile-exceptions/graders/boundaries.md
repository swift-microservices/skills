---
type: llm
focus: { source: file, path: boundaries.md }
---

PASS if the note:

- Honors the AGENTS.md profile, preserving the collision-safe module names and direct WebAuthn standard types/concrete manager in Core while keeping infrastructure clients behind ports.
- Gives all four user operations an explicit `subject: UserIdentity`; derives the account ID from the subject; omits input carriers for auth-code creation and beginning registration; keeps only passwords or the registration credential in the other inputs.
- Passes the verified RPC caller separately from operation data, preserves and validates the authenticator-assigned credential ID, keeps database generation for service-owned IDs, and distinguishes IDs from retry keys.
- Allows concrete policy values with `.standard` initializer defaults without demanding policy protocols.
- Treats the JWT-role route-collection gate as additional security with no database lookup while retaining resource and business authorization in the receiving use case.
- Permits the bounded refresh-rotation read only to preserve a usable credential on dependency failure, with rollback and a deadline below the pool wait budget; excludes remote writes and workflow calls from that exception.
- Adds no artificial database/scope dependency to operations using only nontransactional stores or computation.

FAIL if any required boundary is contradicted or the response rewrites unrelated infrastructure.
