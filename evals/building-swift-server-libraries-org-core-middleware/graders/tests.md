---
type: llm
focus: { source: file, path: Tests/AcmeCoreTests/UserSettingsMiddlewareTests.swift }
---

PASS if the tests use swift-testing and Hummingbird's in-memory router testing (no live server or database), and prove that with a bound user the route observes `ServiceContext.current?.postgresSettings` equal to `.user(identity)` (or `app.caller_user_id` set to the lowercased id), and that with no user bound the route observes no settings.
FAIL if a test starts a server or connects to Postgres, uses XCTest, or covers only one of the two branches.
