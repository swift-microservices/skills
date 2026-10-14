---
type: llm
focus: { source: file, path: acme-sdk/Sources/AcmeSDK/AcmeAuthenticationClient.swift }
---

PASS if all of these hold:
- The type conforms to swift-openapi-token-authentication's `AuthenticationClient`.
- `refreshAuthentication(refreshToken:)` calls the generated refresh operation through a client that carries the refresh token as a bearer token, for example by passing a bearer-token `ClientMiddleware` (which may be defined in another file) or setting the `Authorization` header, and that client carries no `AuthenticationMiddleware`.
- It throws `AuthenticationClientError` with `.invalidRefreshToken` only when the response status is 401.

FAIL if a status other than 401 becomes `.invalidRefreshToken`, the refresh request goes through `AuthenticationMiddleware`, or the refresh token is not sent.
Grade only against these criteria; do not fail for issues they do not mention.
