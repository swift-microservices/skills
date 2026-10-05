---
type: llm
focus: { source: file, path: acme-api/Sources/API/Controllers/ProfileController.swift }
---

PASS if the profile routes are registered for the requiring tier (an `addAuthenticatedRoutes`-style method over `IdentityRequestContext`) and call the users stub's own-profile RPCs without a user id in the path, the body, or the request message; the forwarded token names the caller.

FAIL if a route for the caller's own profile takes a user id, copies the identity's user id into the request message, or compares a path id with the identity in the handler.
