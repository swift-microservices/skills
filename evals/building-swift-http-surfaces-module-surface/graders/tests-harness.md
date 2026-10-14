---
type: llm
focus: { source: file, path: Tests/CatalogHTTPTests/CatalogHTTPTests.swift }
---

PASS if all of these hold:
- The tests use swift-testing and drive the router through HummingbirdTesting (`.router`), with no live server or database.
- The router is composed with the same tiers and middleware as the serve command, over mocked use-case protocols.
- Tokens come from a real `JWTIssuer<UserIdentity>` and `JWTAuthenticator<UserIdentity>` over a throwaway key, so the bearer middleware runs as shipped.

FAIL if the file is missing, the tests use XCTest, start a server or database, or bypass the bearer middleware with a fake authenticator that accepts any token.
Grade only against these criteria; do not fail for issues they do not mention.
