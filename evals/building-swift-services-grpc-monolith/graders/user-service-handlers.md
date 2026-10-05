---
type: llm
focus: { source: file, path: acme-backend/Sources/UsersGRPC/Users/UserService.swift }
---

PASS if all of these hold in the users conformance:
- The handlers are grouped by who may call them: sign-up and sign-in require nothing, the caller's own profile starts with `requireUser()`, and any administrator handler starts with `requireAdministrator()`.
- The profile handler passes the verified principal as `subject:` and takes no user id from the request; the token names the caller.
- Each handler calls one use case through its single `callAsFunction`.

FAIL if the profile handler reads a user id from the request, even to compare it with the token; a caller's-own or administrator handler calls its use case before requiring the principal; or one handler serves both the caller's own record and an administrator's read of any user.
